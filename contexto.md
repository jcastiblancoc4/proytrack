# ANÁLISIS COMPLETO DEL PROYECTO PROYTRACK

**Fecha de Análisis**: 13 de diciembre de 2025
**Versión de Rails**: 7.1.5
**Base de Datos**: MongoDB (Mongoid ODM)

---

## 1. RESUMEN EJECUTIVO

**Proytrack** es una aplicación web de gestión de proyectos desarrollada con Ruby on Rails 7.1 que permite a los usuarios crear, administrar y hacer seguimiento de proyectos con sus respectivos gastos. La aplicación utiliza MongoDB como base de datos (a través de Mongoid ODM), Devise para autenticación, y cuenta con un sistema de compartición de proyectos entre usuarios con control de acceso.

**Características Principales**:
- Gestión de proyectos con identificadores únicos autogenerados
- Seguimiento de gastos por proyecto con categorización
- Sistema de compartición de proyectos con permisos diferenciados
- Estados de ejecución y pago configurables
- Interfaz moderna con Tailwind CSS y Alpine.js
- Despliegue automatizado con GitHub Actions
- Localización completa en español

---

## 2. ARQUITECTURA GENERAL

### 2.1 Stack Tecnológico

| Componente | Tecnología | Versión |
|------------|------------|---------|
| Lenguaje | Ruby | 3.3.0 |
| Framework | Rails | 7.1.5 |
| Base de Datos | MongoDB | N/A |
| ORM | Mongoid | ~> 9.0 |
| Autenticación | Devise | ~> 4.9 |
| Frontend CSS | Tailwind CSS | v3 |
| Frontend JS | Alpine.js | v3 (CDN) |
| Módulos JS | Importmap | N/A |
| Servidor Web | Puma | ~> 6.0 |
| Manejo de Dinero | money-rails | N/A |

### 2.2 Estructura de Directorios

```
/home/juan-pablo/.rbenv/proytrack/
├── app/
│   ├── controllers/        # Controladores (5 archivos)
│   ├── models/             # Modelos Mongoid (4 modelos)
│   ├── views/              # Vistas ERB
│   │   ├── layouts/
│   │   ├── home/
│   │   ├── projects/
│   │   ├── expenses/
│   │   └── devise/
│   ├── helpers/            # Helpers (vacíos)
│   ├── assets/
│   │   ├── stylesheets/    # Tailwind CSS
│   │   └── images/
│   ├── channels/           # ActionCable (no usado)
│   ├── jobs/               # ActiveJob (no usado)
│   └── mailers/            # Mailers (no usado)
├── config/
│   ├── environments/       # Configuración por entorno
│   ├── initializers/       # Inicializadores
│   ├── locales/            # i18n (español)
│   ├── application.rb
│   ├── routes.rb
│   ├── mongoid.yml
│   ├── puma.rb
│   └── importmap.rb
├── db/                     # No usado (Mongoid no usa migraciones)
├── log/                    # Logs de la aplicación
├── tmp/                    # Cache y archivos temporales
├── .github/
│   └── workflows/
│       └── deploy.yml      # CI/CD con GitHub Actions
├── Gemfile
├── Dockerfile
├── Procfile
├── Procfile.dev
├── README.md
└── CLAUDE.md
```

---

## 3. MODELOS DE DATOS

La aplicación utiliza **Mongoid** (MongoDB ODM) en lugar de ActiveRecord. No hay migraciones tradicionales de base de datos; los esquemas se definen directamente en los modelos.

### 3.1 User (Usuario)

**Archivo**: `app/models/user.rb`

**Propósito**: Gestión de usuarios con autenticación Devise.

**Campos**:
```ruby
field :email,                  type: String  # Normalizado a minúsculas
field :encrypted_password,     type: String
field :reset_password_token,   type: String
field :reset_password_sent_at, type: Time
field :remember_created_at,    type: Time
# Timestamps automáticos: created_at, updated_at
```

**Módulos Devise**:
- `:database_authenticatable` - Autenticación con base de datos
- `:registerable` - Permite registro de nuevos usuarios
- `:recoverable` - Recuperación de contraseña
- `:rememberable` - Recordar sesión
- `:validatable` - Validaciones de email y contraseña

**Relaciones**:
```ruby
has_many :projects, dependent: :destroy
# Proyectos de los que es propietario

has_many :shared_projects, dependent: :destroy
# Registros de proyectos compartidos con este usuario

has_many :shared_by_me_projects,
         class_name: 'SharedProject',
         foreign_key: 'shared_by_id'
# Proyectos que este usuario compartió con otros
```

**Métodos Personalizados**:
```ruby
def shared_with_me_projects
  # Retorna los proyectos compartidos con el usuario actual
  # Workaround porque Mongoid no soporta has_many :through
  Project.in(id: shared_projects.pluck(:project_id))
end
```

**Validaciones**:
- Email: presencia, formato válido, unicidad (case-insensitive)
- Contraseña: presencia, longitud mínima (6 caracteres), confirmación

**Callbacks**:
- `before_save :downcase_email` - Normaliza email a minúsculas

---

### 3.2 Project (Proyecto)

**Archivo**: `app/models/project.rb`

**Propósito**: Modelo central que representa un proyecto de trabajo.

**Campos**:
```ruby
field :name,               type: String    # Nombre del proyecto
field :project_identifier, type: String    # Ej: PROY-2025-001
field :purchase_order,     type: String    # Orden de compra
field :quoted_value,       type: Money     # Valor cotizado (COP)
field :locality,           type: String    # Localidad
field :settlement_date,    type: Date      # Fecha de liquidación
field :payment_status,     type: Integer, default: 0    # Enum
field :execution_status,   type: Integer, default: 0    # Enum
# Timestamps automáticos: created_at, updated_at
```

**Relaciones**:
```ruby
belongs_to :user  # Propietario del proyecto

has_many :expenses, dependent: :destroy
# Gastos asociados al proyecto

has_many :shared_projects, dependent: :destroy
# Registros de compartición
```

**Enums** (usando gem simple_enum):
```ruby
# Estado de pago
as_enum :payment_status, {
  pending: 0,  # Pendiente
  paid: 1      # Pagado
}, field: { type: Integer, default: 0 }

# Estado de ejecución
as_enum :execution_status, {
  pending: 0,    # Pendiente
  running: 1,    # Ejecutando
  stop: 2,       # Pausado
  cancelled: 3,  # Cancelado
  ended: 4       # Terminado
}, field: { type: Integer, default: 0 }
```

**Validaciones**:
```ruby
validates :name, presence: {
  message: "El nombre del proyecto es obligatorio"
}
validates :project_identifier,
          presence: true,
          uniqueness: {
            scope: :user_id,
            case_sensitive: false
          }
validates :purchase_order, presence: true
validates :quoted_value, presence: true
validates :locality, presence: true
```

**Callbacks**:
```ruby
before_validation :generate_project_identifier, on: :create
```

**Métodos Personalizados**:

```ruby
# Control de Acceso
def can_access?(user)
  # El propietario o usuarios con acceso compartido pueden ver
  user == self.user || shared_with_users.include?(user)
end

def can_edit?(user)
  # Solo el propietario puede editar
  user == self.user
end

def shared_with?(user)
  # Verifica si está compartido con un usuario específico
  shared_with_users.include?(user)
end

# Acceso a usuarios compartidos
def shared_with_users
  User.in(id: shared_projects.pluck(:user_id))
end

# Generación de identificador
def generate_project_identifier
  # Formato: PROY-YYYY-NNN
  # Ejemplo: PROY-2025-001, PROY-2025-002
  # Secuencial por año y usuario
  return if project_identifier.present?

  year = Date.current.year
  last_project = user.projects
                    .where(project_identifier: /^PROY-#{year}-/)
                    .order('project_identifier DESC')
                    .first

  if last_project
    last_number = last_project.project_identifier.split('-').last.to_i
    new_number = last_number + 1
  else
    new_number = 1
  end

  self.project_identifier = "PROY-#{year}-#{new_number.to_s.rjust(3, '0')}"
end
```

**Índices** (definidos en el modelo):
```ruby
index({ user_id: 1, project_identifier: 1 }, { unique: true })
index({ user_id: 1, created_at: -1 })
```

---

### 3.3 Expense (Gasto)

**Archivo**: `app/models/expense.rb`

**Propósito**: Registro de gastos asociados a un proyecto.

**Campos**:
```ruby
field :description,  type: String  # Descripción del gasto
field :amount,       type: Money   # Monto (COP)
field :expense_type, type: Integer # Enum: tipo de gasto
field :expense_date, type: Date    # Fecha del gasto
# Timestamps automáticos: created_at, updated_at
```

**Relaciones**:
```ruby
belongs_to :project
```

**Enum**:
```ruby
as_enum :expense_type, {
  payroll: 0,   # Nómina
  hardware: 1,  # Ferretería
  fuel: 2       # Combustible
}, field: { type: Integer, default: 0 }
```

**Validaciones**:
```ruby
validates :description, presence: true
validates :amount, presence: true
validates :expense_type, presence: true
validates :expense_date, presence: true
```

**Índices**:
```ruby
index({ project_id: 1, expense_date: -1 })
index({ project_id: 1, expense_type: 1 })
```

---

### 3.4 SharedProject (Proyecto Compartido)

**Archivo**: `app/models/shared_project.rb`

**Propósito**: Modelo de unión (join model) para gestionar el acceso compartido a proyectos.

**Campos**:
```ruby
# Referencias ObjectId de MongoDB
field :project_id,   type: BSON::ObjectId
field :user_id,      type: BSON::ObjectId
field :shared_by_id, type: BSON::ObjectId
# Timestamps automáticos: created_at, updated_at
```

**Relaciones**:
```ruby
belongs_to :project
belongs_to :user          # Usuario que recibe acceso
belongs_to :shared_by, class_name: 'User'  # Usuario que comparte
```

**Validaciones**:
```ruby
validates :project_id, presence: true
validates :user_id, presence: true,
                    uniqueness: { scope: :project_id }
validates :shared_by_id, presence: true

# Validación personalizada: no compartir consigo mismo
validate :cannot_share_with_self

# Validación personalizada: no compartir con el propietario
validate :cannot_share_with_owner

private

def cannot_share_with_self
  if user_id == shared_by_id
    errors.add(:user_id, "no puede ser el mismo usuario")
  end
end

def cannot_share_with_owner
  if project && user_id == project.user_id
    errors.add(:user_id, "no puede ser el propietario del proyecto")
  end
end
```

**Scopes**:
```ruby
scope :for_user, ->(user) { where(user: user) }
scope :for_project, ->(project) { where(project: project) }
```

**Índices**:
```ruby
index({ project_id: 1, user_id: 1 }, { unique: true })
index({ user_id: 1, created_at: -1 })
index({ shared_by_id: 1, created_at: -1 })
```

---

## 4. CONTROLADORES

### 4.1 ApplicationController

**Archivo**: `app/controllers/application_controller.rb`

**Código**:
```ruby
class ApplicationController < ActionController::Base
  # Controlador base vacío
  # Toda la autenticación se maneja via Devise
end
```

---

### 4.2 HomeController

**Archivo**: `app/controllers/home_controller.rb`

**Propósito**: Página principal con listado de proyectos.

**Autenticación**:
```ruby
before_action :authenticate_user!
```

**Acciones**:

#### `index` (GET /)
```ruby
def index
  # Combina proyectos propios y compartidos
  @projects = (current_user.projects.to_a +
               current_user.shared_with_me_projects.to_a)

  # Ordena por última actualización (proyecto o gasto más reciente)
  @projects.sort_by! do |project|
    [project.updated_at,
     project.expenses.maximum(:updated_at)].compact.max || project.created_at
  end.reverse!
end
```

**Variables de vista**:
- `@projects`: Array de proyectos ordenados por última actividad

---

### 4.3 ProjectsController

**Archivo**: `app/controllers/projects_controller.rb`

**Propósito**: CRUD de proyectos con control de acceso.

**Autenticación**:
```ruby
before_action :authenticate_user!
before_action :set_project, only: [:show, :edit, :update, :destroy, :update_status]
before_action :authorize_access, only: [:show]
before_action :authorize_edit, only: [:edit, :update, :destroy]
```

**Acciones**:

#### `show` (GET /projects/:id)
```ruby
def show
  @expenses = @project.expenses.order(expense_date: :desc)
  @can_edit = @project.can_edit?(current_user)
  # Vista: muestra detalles del proyecto y gastos
end
```

#### `new` (GET /projects/new)
```ruby
def new
  @project = Project.new
end
```

#### `create` (POST /projects)
```ruby
def create
  @project = current_user.projects.build(project_params)

  if @project.save
    redirect_to root_path, notice: 'Proyecto creado exitosamente'
  else
    render :new, status: :unprocessable_entity
  end
end
```

#### `edit` (GET /projects/:id/edit)
```ruby
def edit
  # Renderiza formulario de edición
end
```

#### `update` (PATCH /projects/:id)
```ruby
def update
  if @project.update(project_params)
    redirect_path = params[:from] == 'home' ? root_path : project_path(@project)
    redirect_to redirect_path, notice: 'Proyecto actualizado exitosamente'
  else
    render :edit, status: :unprocessable_entity
  end
end
```

#### `destroy` (DELETE /projects/:id)
```ruby
def destroy
  @project.destroy
  redirect_to root_path, notice: 'Proyecto eliminado exitosamente'
end
```

#### `update_status` (PATCH /projects/:id/update_status)
```ruby
def update_status
  # Actualiza execution_status
  if params[:execution_status]
    @project.execution_status = params[:execution_status]

    # Si el estado es "ended", guarda la fecha de liquidación
    if params[:execution_status] == 'ended'
      @project.settlement_date = params[:settlement_date] || Date.current
    else
      @project.settlement_date = nil
    end

    if @project.save
      redirect_to root_path, notice: 'Estado actualizado exitosamente'
    else
      redirect_to root_path, alert: 'Error al actualizar el estado'
    end
  end
end
```

**Métodos Privados**:

```ruby
private

def set_project
  @project = Project.find(params[:id])
rescue Mongoid::Errors::DocumentNotFound
  redirect_to root_path, alert: 'Proyecto no encontrado'
end

def authorize_access
  unless @project.can_access?(current_user)
    redirect_to root_path, alert: 'No tienes acceso a este proyecto'
  end
end

def authorize_edit
  unless @project.can_edit?(current_user)
    redirect_to root_path, alert: 'No tienes permisos para editar este proyecto'
  end
end

def project_params
  params.require(:project).permit(
    :name, :purchase_order, :quoted_value, :locality,
    :payment_status, :execution_status
  )
end
```

---

### 4.4 ExpensesController

**Archivo**: `app/controllers/expenses_controller.rb`

**Propósito**: CRUD de gastos dentro de un proyecto.

**Autenticación y Autorización**:
```ruby
before_action :authenticate_user!
before_action :set_project
before_action :set_expense, only: [:edit, :update, :destroy]
before_action :check_edit_permission, only: [:new, :create, :edit, :update, :destroy]
```

**Acciones**:

#### `index` (GET /projects/:project_id/expenses)
```ruby
def index
  @expenses = @project.expenses.order(expense_date: :desc)
end
```

#### `new` (GET /projects/:project_id/expenses/new)
```ruby
def new
  @expense = @project.expenses.build
end
```

#### `create` (POST /projects/:project_id/expenses)
```ruby
def create
  @expense = @project.expenses.build(expense_params)

  if @expense.save
    redirect_path = params[:from] == 'home' ? root_path : project_path(@project)
    redirect_to redirect_path, notice: 'Gasto agregado exitosamente'
  else
    render :new, status: :unprocessable_entity
  end
end
```

#### `edit` (GET /projects/:project_id/expenses/:id/edit)
```ruby
def edit
  # Renderiza formulario de edición
end
```

#### `update` (PATCH /projects/:project_id/expenses/:id)
```ruby
def update
  if @expense.update(expense_params)
    redirect_path = params[:from] == 'home' ? root_path : project_path(@project)
    redirect_to redirect_path, notice: 'Gasto actualizado exitosamente'
  else
    render :edit, status: :unprocessable_entity
  end
end
```

#### `destroy` (DELETE /projects/:project_id/expenses/:id)
```ruby
def destroy
  @expense.destroy
  redirect_to project_path(@project), notice: 'Gasto eliminado exitosamente'
end
```

**Métodos Privados**:

```ruby
private

def set_project
  @project = Project.find(params[:project_id])
rescue Mongoid::Errors::DocumentNotFound
  redirect_to root_path, alert: 'Proyecto no encontrado'
end

def set_expense
  @expense = @project.expenses.find(params[:id])
rescue Mongoid::Errors::DocumentNotFound
  redirect_to project_path(@project), alert: 'Gasto no encontrado'
end

def check_edit_permission
  unless @project.can_edit?(current_user)
    redirect_to root_path,
                alert: 'Solo el propietario puede gestionar gastos'
  end
end

def expense_params
  params.require(:expense).permit(
    :description, :amount, :expense_type, :expense_date
  )
end
```

---

### 4.5 SharedProjectsController

**Archivo**: `app/controllers/shared_projects_controller.rb`

**Propósito**: Gestión de compartición de proyectos entre usuarios.

**Autenticación**:
```ruby
before_action :authenticate_user!
before_action :set_project, only: [:create, :destroy]
```

**Acciones**:

#### `create` (POST /projects/:project_id/shared_projects)
```ruby
def create
  # 1. Buscar usuario por email
  user = User.find_by(email: params[:email])

  if user.nil?
    redirect_to project_path(@project),
                alert: 'Usuario no encontrado'
    return
  end

  # 2. Validar que no sea el propietario
  if user == @project.user
    redirect_to project_path(@project),
                alert: 'No puedes compartir el proyecto contigo mismo'
    return
  end

  # 3. Validar que no esté ya compartido
  if @project.shared_with?(user)
    redirect_to project_path(@project),
                alert: 'El proyecto ya está compartido con este usuario'
    return
  end

  # 4. Crear compartición
  shared_project = @project.shared_projects.build(
    user: user,
    shared_by: current_user
  )

  if shared_project.save
    redirect_to project_path(@project),
                notice: "Proyecto compartido con #{user.email}"
  else
    redirect_to project_path(@project),
                alert: 'Error al compartir el proyecto'
  end

rescue Mongoid::Errors::DocumentNotFound
  redirect_to root_path, alert: 'Proyecto no encontrado'
rescue => e
  redirect_to project_path(@project),
              alert: "Error: #{e.message}"
end
```

#### `destroy` (DELETE /projects/:project_id/shared_projects/:id)
```ruby
def destroy
  shared_project = @project.shared_projects.find(params[:id])
  shared_project.destroy

  redirect_to project_path(@project),
              notice: 'Acceso revocado exitosamente'
rescue Mongoid::Errors::DocumentNotFound
  redirect_to project_path(@project),
              alert: 'Registro de compartición no encontrado'
end
```

**Métodos Privados**:

```ruby
private

def set_project
  @project = Project.find(params[:project_id])

  unless @project.can_edit?(current_user)
    redirect_to root_path,
                alert: 'Solo el propietario puede compartir proyectos'
  end
rescue Mongoid::Errors::DocumentNotFound
  redirect_to root_path, alert: 'Proyecto no encontrado'
end
```

---

## 5. VISTAS Y FRONTEND

### 5.1 Layout Principal

**Archivo**: `app/views/layouts/application.html.erb`

**Características**:
- Meta tags (viewport, CSRF, CSP)
- Tailwind CSS via `stylesheet_link_tag`
- Alpine.js v3 (CDN)
- Rails UJS via Importmap
- Sistema de flash messages con auto-desaparición
- Header con usuario y logout

**Estructura**:
```erb
<!DOCTYPE html>
<html>
  <head>
    <title>Proytrack</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
    <script src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
  </head>
  <body class="bg-gray-50">
    <!-- Header con usuario y logout -->
    <% if user_signed_in? %>
      <header class="bg-white shadow">
        <!-- Usuario y botón de cerrar sesión -->
      </header>
    <% end %>

    <!-- Flash messages con auto-desaparición -->
    <div id="flash-messages">
      <!-- Mensajes notice, alert, error -->
    </div>

    <!-- Contenido principal -->
    <main>
      <%= yield %>
    </main>
  </body>
</html>
```

**Estilos de Flash Messages**:
- `notice`: Verde (éxito)
- `alert`: Amarillo (advertencia)
- `error`: Rojo (error)
- Auto-desaparición: 6 segundos

---

### 5.2 Vista Principal (Home)

**Archivo**: `app/views/home/index.html.erb`

**Propósito**: Dashboard con todos los proyectos del usuario.

**Características**:
- Búsqueda en tiempo real (JavaScript)
- Grid responsive de tarjetas
- Información de valores (cotizado, gastado, diferencia)
- Estados con colores (badges)
- Modales para actualizar estado de ejecución

**Componentes JavaScript**:

```javascript
// Búsqueda en tiempo real
function searchProjects() {
  const searchTerm = document.getElementById('search-input').value.toLowerCase();
  const projectCards = document.querySelectorAll('.project-card');

  projectCards.forEach(card => {
    const name = card.dataset.name.toLowerCase();
    const identifier = card.dataset.identifier.toLowerCase();

    if (name.includes(searchTerm) || identifier.includes(searchTerm)) {
      card.style.display = '';
    } else {
      card.style.display = 'none';
    }
  });
}

// Modal para cambiar estado de ejecución
function openStatusModal(projectId, currentStatus) {
  // Implementación del modal con Alpine.js
}
```

**Estructura de Tarjeta de Proyecto**:
```erb
<div class="project-card"
     data-name="<%= project.name %>"
     data-identifier="<%= project.project_identifier %>">
  <!-- Header con nombre y acciones -->
  <div class="flex justify-between items-start">
    <h3><%= project.name %></h3>
    <% if project.can_edit?(current_user) %>
      <!-- Botones de editar y eliminar -->
    <% end %>
  </div>

  <!-- Información del proyecto -->
  <div class="space-y-2">
    <p><strong>ID:</strong> <%= project.project_identifier %></p>
    <p><strong>Orden:</strong> <%= project.purchase_order %></p>
    <p><strong>Localidad:</strong> <%= project.locality %></p>
  </div>

  <!-- Valores monetarios -->
  <div class="grid grid-cols-3 gap-2">
    <div>
      <span class="text-sm">Cotizado</span>
      <p class="font-bold"><%= humanized_money project.quoted_value %></p>
    </div>
    <div>
      <span class="text-sm">Gastado</span>
      <p class="font-bold"><%= humanized_money expenses_total %></p>
    </div>
    <div>
      <span class="text-sm">Diferencia</span>
      <p class="font-bold <%= difference_class %>">
        <%= humanized_money difference %>
      </p>
    </div>
  </div>

  <!-- Estados -->
  <div class="flex gap-2">
    <%= status_badge(project.execution_status_text) %>
    <%= status_badge(project.payment_status_text) %>
  </div>
</div>
```

---

### 5.3 Vista de Detalle de Proyecto

**Archivo**: `app/views/projects/show.html.erb`

**Propósito**: Vista detallada de un proyecto con sus gastos.

**Secciones**:

1. **Header con información del proyecto**
   - Nombre, ID, orden de compra, localidad
   - Botones de acción (editar, eliminar, compartir)
   - Solo visible para propietario

2. **Resumen de gastos**
   ```erb
   <div class="grid grid-cols-3 gap-4">
     <div>
       <h4>Total Gastado</h4>
       <p><%= humanized_money @project.expenses.sum(&:amount) %></p>
     </div>
     <div>
       <h4>Saldo Restante</h4>
       <p><%= humanized_money (@project.quoted_value - expenses_total) %></p>
     </div>
     <div>
       <h4>Cantidad de Gastos</h4>
       <p><%= @project.expenses.count %></p>
     </div>
   </div>
   ```

3. **Sección de usuarios con acceso** (solo propietario)
   - Lista de usuarios compartidos
   - Botón para revocar acceso
   - Formulario para compartir con nuevo usuario

4. **Formulario de nuevo gasto** (solo propietario)
   ```erb
   <%= form_with model: [@project, @project.expenses.build],
                 data: { controller: "expense-form" } do |f| %>
     <%= f.text_area :description %>
     <%= f.text_field :amount %>
     <%= f.select :expense_type, Expense.expense_types_for_select %>
     <%= f.date_field :expense_date %>
     <%= f.submit "Agregar Gasto" %>
   <% end %>
   ```

5. **Tabla de gastos con accordion**
   - Filas expandibles con detalles
   - Acciones de editar y eliminar (solo propietario)
   - Ordenados por fecha descendente

**Modales**:

```erb
<!-- Modal para actualizar estado de ejecución -->
<div id="status-modal" class="hidden fixed inset-0 bg-gray-600 bg-opacity-50">
  <div class="bg-white rounded-lg">
    <%= form_with url: update_status_project_path(@project),
                  method: :patch do |f| %>
      <%= f.select :execution_status,
                   Project.execution_statuses_for_select %>

      <!-- Campo de fecha de liquidación (solo si ended) -->
      <div id="settlement-date-field" class="hidden">
        <%= f.date_field :settlement_date, value: Date.current %>
      </div>

      <%= f.submit "Actualizar" %>
    <% end %>
  </div>
</div>

<!-- Modal para compartir proyecto -->
<div id="share-modal" class="hidden fixed inset-0 bg-gray-600 bg-opacity-50">
  <div class="bg-white rounded-lg">
    <%= form_with url: project_shared_projects_path(@project),
                  method: :post do |f| %>
      <%= f.email_field :email, placeholder: "Email del usuario" %>
      <%= f.submit "Compartir" %>
    <% end %>
  </div>
</div>
```

---

### 5.4 Formularios de Proyecto

#### app/views/projects/new.html.erb

**Propósito**: Crear nuevo proyecto.

**Características**:
- Validación en cliente con JavaScript
- Formateo automático de valores monetarios
- Información contextual en sidebar

```erb
<div class="container mx-auto px-4 py-8">
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
    <!-- Columna principal: Formulario -->
    <div class="lg:col-span-2">
      <h1 class="text-3xl font-bold mb-6">Nuevo Proyecto</h1>

      <%= form_with model: @project,
                    data: { controller: "project-form" } do |f| %>
        <!-- Nombre del proyecto -->
        <div class="mb-4">
          <%= f.label :name, "Nombre del Proyecto", class: "block mb-2" %>
          <%= f.text_field :name,
                          class: "w-full border rounded px-3 py-2",
                          required: true %>
        </div>

        <!-- Orden de compra -->
        <div class="mb-4">
          <%= f.label :purchase_order, "Orden de Compra", class: "block mb-2" %>
          <%= f.text_field :purchase_order,
                          class: "w-full border rounded px-3 py-2",
                          required: true %>
        </div>

        <!-- Valor cotizado con formateo -->
        <div class="mb-4">
          <%= f.label :quoted_value, "Valor Cotizado", class: "block mb-2" %>
          <%= f.text_field :quoted_value,
                          class: "w-full border rounded px-3 py-2",
                          required: true,
                          data: { action: "input->project-form#formatCurrency" } %>
          <p class="text-sm text-gray-500 mt-1">
            Ejemplo: 1.000.000
          </p>
        </div>

        <!-- Localidad -->
        <div class="mb-4">
          <%= f.label :locality, "Localidad", class: "block mb-2" %>
          <%= f.text_field :locality,
                          class: "w-full border rounded px-3 py-2",
                          required: true %>
        </div>

        <!-- Botones de acción -->
        <div class="flex gap-4">
          <%= f.submit "Crear Proyecto",
                      class: "bg-blue-600 text-white px-6 py-2 rounded" %>
          <%= link_to "Cancelar", root_path,
                     class: "bg-gray-300 px-6 py-2 rounded" %>
        </div>
      <% end %>
    </div>

    <!-- Columna secundaria: Información -->
    <div class="lg:col-span-1">
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
        <h3 class="font-bold text-lg mb-4">Información</h3>
        <ul class="space-y-2 text-sm">
          <li>• El ID del proyecto se generará automáticamente</li>
          <li>• Formato: PROY-YYYY-NNN</li>
          <li>• Los valores monetarios se guardan en COP</li>
          <li>• Podrás agregar gastos después de crear el proyecto</li>
        </ul>
      </div>
    </div>
  </div>
</div>
```

#### app/views/projects/edit.html.erb

Similar a `new.html.erb` pero con campos pre-llenados y:
- Selects para `payment_status` y `execution_status`
- Campo `project_identifier` deshabilitado (no editable)
- Parámetro `from` para redirección correcta

---

### 5.5 Formularios de Gastos

#### app/views/expenses/new.html.erb

**Nota**: Esta vista no se usa actualmente. Los gastos se crean desde el show del proyecto.

#### app/views/expenses/edit.html.erb

```erb
<div class="container mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold mb-6">Editar Gasto</h1>

  <%= form_with model: [@project, @expense],
                url: project_expense_path(@project, @expense),
                data: { controller: "expense-form" } do |f| %>
    <!-- Descripción con auto-resize -->
    <div class="mb-4">
      <%= f.label :description, "Descripción", class: "block mb-2" %>
      <%= f.text_area :description,
                     class: "w-full border rounded px-3 py-2",
                     rows: 3,
                     required: true,
                     data: { action: "input->expense-form#autoResize" } %>
    </div>

    <!-- Monto con formateo -->
    <div class="mb-4">
      <%= f.label :amount, "Monto", class: "block mb-2" %>
      <%= f.text_field :amount,
                      value: number_with_delimiter(@expense.amount.to_i, delimiter: '.'),
                      class: "w-full border rounded px-3 py-2",
                      required: true,
                      data: { action: "input->expense-form#formatCurrency" } %>
    </div>

    <!-- Tipo de gasto -->
    <div class="mb-4">
      <%= f.label :expense_type, "Tipo", class: "block mb-2" %>
      <%= f.select :expense_type,
                  Expense.expense_types_for_select,
                  {},
                  class: "w-full border rounded px-3 py-2",
                  required: true %>
    </div>

    <!-- Fecha del gasto -->
    <div class="mb-4">
      <%= f.label :expense_date, "Fecha", class: "block mb-2" %>
      <%= f.date_field :expense_date,
                      class: "w-full border rounded px-3 py-2",
                      required: true %>
    </div>

    <!-- Hidden field para redirección -->
    <%= hidden_field_tag :from, params[:from] %>

    <!-- Botones -->
    <div class="flex gap-4">
      <%= f.submit "Actualizar Gasto",
                  class: "bg-blue-600 text-white px-6 py-2 rounded" %>
      <%= link_to "Cancelar",
                 params[:from] == 'home' ? root_path : project_path(@project),
                 class: "bg-gray-300 px-6 py-2 rounded" %>
    </div>
  <% end %>
</div>
```

---

### 5.6 Vistas de Autenticación (Devise)

#### app/views/devise/sessions/new.html.erb (Login)

```erb
<div class="min-h-screen flex items-center justify-center bg-gray-100">
  <div class="bg-white p-8 rounded-lg shadow-md w-full max-w-md">
    <h2 class="text-2xl font-bold mb-6 text-center">Iniciar Sesión</h2>

    <%= form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>
      <!-- Email -->
      <div class="mb-4">
        <%= f.label :email, "Correo Electrónico", class: "block mb-2" %>
        <%= f.email_field :email,
                         autofocus: true,
                         autocomplete: "email",
                         class: "w-full border rounded px-3 py-2" %>
      </div>

      <!-- Contraseña -->
      <div class="mb-4">
        <%= f.label :password, "Contraseña", class: "block mb-2" %>
        <%= f.password_field :password,
                            autocomplete: "current-password",
                            class: "w-full border rounded px-3 py-2" %>
      </div>

      <!-- Recordarme -->
      <% if devise_mapping.rememberable? %>
        <div class="mb-4">
          <%= f.check_box :remember_me, class: "mr-2" %>
          <%= f.label :remember_me, "Recordarme" %>
        </div>
      <% end %>

      <!-- Botón de submit -->
      <div class="mb-4">
        <%= f.submit "Iniciar Sesión",
                    class: "w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700" %>
      </div>
    <% end %>

    <!-- Enlaces -->
    <%= render "devise/shared/links" %>
  </div>
</div>
```

#### app/views/devise/registrations/new.html.erb (Registro)

Similar estructura al login con:
- Campo de confirmación de contraseña
- Validaciones de errores mostradas
- Enlace para volver a login

---

## 6. RUTAS

**Archivo**: `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Página principal
  root "home#index"

  # Autenticación Devise
  devise_for :users
  # Genera: /users/sign_in, /users/sign_up, /users/sign_out,
  #         /users/password/new, etc.

  # Proyectos
  resources :projects, only: [:show, :new, :create, :edit, :update, :destroy] do
    # Ruta personalizada para actualizar estado
    member do
      patch :update_status  # PATCH /projects/:id/update_status
    end

    # Gastos anidados
    resources :expenses, except: [:show]
    # Genera: GET/POST/PATCH/DELETE /projects/:project_id/expenses

    # Compartición anidada
    resources :shared_projects, only: [:create, :destroy]
    # Genera: POST /projects/:project_id/shared_projects
    #         DELETE /projects/:project_id/shared_projects/:id
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
```

**Tabla de Rutas Generadas**:

| Verbo | Ruta | Controlador#Acción | Propósito |
|-------|------|-------------------|-----------|
| GET | / | home#index | Página principal |
| GET | /projects/:id | projects#show | Ver proyecto |
| GET | /projects/new | projects#new | Formulario nuevo proyecto |
| POST | /projects | projects#create | Crear proyecto |
| GET | /projects/:id/edit | projects#edit | Formulario editar proyecto |
| PATCH | /projects/:id | projects#update | Actualizar proyecto |
| DELETE | /projects/:id | projects#destroy | Eliminar proyecto |
| PATCH | /projects/:id/update_status | projects#update_status | Actualizar estado ejecución |
| GET | /projects/:pid/expenses | expenses#index | Listar gastos |
| GET | /projects/:pid/expenses/new | expenses#new | Formulario nuevo gasto |
| POST | /projects/:pid/expenses | expenses#create | Crear gasto |
| GET | /projects/:pid/expenses/:id/edit | expenses#edit | Formulario editar gasto |
| PATCH | /projects/:pid/expenses/:id | expenses#update | Actualizar gasto |
| DELETE | /projects/:pid/expenses/:id | expenses#destroy | Eliminar gasto |
| POST | /projects/:pid/shared_projects | shared_projects#create | Compartir proyecto |
| DELETE | /projects/:pid/shared_projects/:id | shared_projects#destroy | Revocar acceso |
| GET | /users/sign_in | devise/sessions#new | Login |
| POST | /users/sign_in | devise/sessions#create | Autenticar |
| DELETE | /users/sign_out | devise/sessions#destroy | Logout |
| GET | /users/sign_up | devise/registrations#new | Registro |
| POST | /users | devise/registrations#create | Crear cuenta |

---

## 7. CONFIGURACIÓN

### 7.1 Configuración de la Aplicación

**Archivo**: `config/application.rb`

```ruby
require_relative "boot"
require "rails"

# Carga solo los frameworks necesarios
require "active_model/railtie"
require "active_job/railtie"
# require "active_record/railtie"  # NO usado (Mongoid)
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

module Proytrack
  class Application < Rails::Application
    # Versión del framework
    config.load_defaults 7.1

    # Configuración regional
    config.i18n.default_locale = :es
    config.time_zone = "Bogota"

    # Autoload paths
    config.autoload_lib(ignore: %w(assets tasks))

    # Generadores (sin usar ActiveRecord)
    config.generators do |g|
      g.orm :mongoid
    end
  end
end
```

---

### 7.2 Configuración de MongoDB

**Archivo**: `config/mongoid.yml`

```yaml
development:
  clients:
    default:
      # MongoDB Atlas Cloud
      uri: mongodb+srv://jpcast:pro123@proytrack.la0ps9g.mongodb.net/proytrack_development
      options:
        server_selection_timeout: 5
        ssl: true
        ssl_verify: false
  options:
    log_level: :info

test:
  clients:
    default:
      # MongoDB Atlas Cloud
      uri: mongodb+srv://jpcast:pro123@proytrack.la0ps9g.mongodb.net/proytrack_test
      options:
        server_selection_timeout: 5
        ssl: true
        ssl_verify: false
  options:
    log_level: :warn

production:
  clients:
    default:
      # MongoDB local
      database: proytrack_production
      hosts:
        - 127.0.0.1:27017
      options:
        server_selection_timeout: 5
```

**Notas de Seguridad**:
- ⚠️ Las credenciales están hardcodeadas (debería usar variables de entorno)
- SSL deshabilitado en verificación para desarrollo

---

### 7.3 Configuración del Servidor (Puma)

**Archivo**: `config/puma.rb`

```ruby
# Número máximo de threads
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Puerto (desarrollo)
port ENV.fetch("PORT") { 3000 }

# Entorno
environment ENV.fetch("RAILS_ENV") { "development" }

# PID file
pidfile ENV.fetch("PIDFILE") { "tmp/pids/puma.pid" }

# Workers (producción)
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Preload app para workers
preload_app!

# Permite reinicio remoto
plugin :tmp_restart

# Configuración específica de producción
if ENV.fetch("RAILS_ENV") { "development" } == "production"
  # Usar socket UNIX en lugar de puerto TCP
  bind "unix:///home/deploy/proytrack/tmp/sockets/puma.sock"

  # Logs
  stdout_redirect "log/puma.stdout.log", "log/puma.stderr.log", true

  # Daemonize (correr en background)
  # daemonize false  # Systemd se encarga de esto
end
```

---

### 7.4 Inicializadores

#### config/initializers/devise.rb

```ruby
Devise.setup do |config|
  # ORM
  config.orm = :mongoid

  # Mailer sender
  config.mailer_sender = 'please-change-me-at-config-initializers-devise@example.com'

  # Estrategias de autenticación
  config.authentication_keys = [:email]
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  # Password
  config.password_length = 6..128
  config.reset_password_within = 6.hours

  # Session
  config.timeout_in = 30.minutes
  config.remember_for = 2.weeks

  # Signing out
  config.sign_out_via = :delete
end
```

#### config/initializers/money.rb

```ruby
MoneyRails.configure do |config|
  # Moneda por defecto: Pesos Colombianos
  config.default_currency = :COP

  # Sin centavos para COP
  config.no_cents_if_whole = false

  # Formato
  config.default_format = {
    no_cents_if_whole: false,
    symbol: true,
    sign_before_symbol: false
  }
end
```

#### config/initializers/mongoid.rb

```ruby
Mongoid.configure do |config|
  # Versión objetivo
  config.belongs_to_required_by_default = true
  config.load_defaults "9.0"
end
```

---

### 7.5 Configuración de Entornos

#### config/environments/production.rb (extracto)

```ruby
Rails.application.configure do
  # Code loading
  config.eager_load = true
  config.cache_classes = true

  # Assets
  config.public_file_server.enabled = false
  config.assets.compile = false
  config.assets.digest = true

  # Logging
  config.log_level = :info
  config.log_tags = [:request_id]

  # i18n
  config.i18n.fallbacks = true

  # Security
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: -> request { request.path =~ /health/ } } }

  # Performance
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store
end
```

---

## 8. INTERNACIONALIZACIÓN

**Archivo**: `config/locales/es.yml`

```yaml
es:
  datetime:
    distance_in_words:
      about_x_hours:
        one: "alrededor de 1 hora"
        other: "alrededor de %{count} horas"
      about_x_months:
        one: "alrededor de 1 mes"
        other: "alrededor de %{count} meses"
      # ... más traducciones de tiempo

  activemodel:
    attributes:
      project:
        execution_status:
          pending: "Pendiente"
          running: "Ejecutando"
          stop: "Pausado"
          cancelled: "Cancelado"
          ended: "Terminado"
        payment_status:
          pending: "Pendiente"
          paid: "Pagado"
      expense:
        expense_type:
          payroll: "Nómina"
          hardware: "Ferretería"
          fuel: "Combustible"
```

**Uso en el código**:
```ruby
# En modelo con simple_enum
project.execution_status_text  # => "Ejecutando"
project.payment_status_text    # => "Pagado"
expense.expense_type_text      # => "Nómina"

# En vistas
t('activemodel.attributes.project.execution_status.running')  # => "Ejecutando"
```

---

## 9. AUTENTICACIÓN Y AUTORIZACIÓN

### 9.1 Autenticación (Devise)

**Estrategia**: Database Authenticatable

**Campos de Usuario**:
- `email`: Identificador único (case-insensitive)
- `encrypted_password`: Contraseña hasheada con bcrypt

**Flujo de Registro**:
1. Usuario visita `/users/sign_up`
2. Completa formulario (email, password, password_confirmation)
3. Devise valida y crea usuario
4. Redirige a login
5. Usuario inicia sesión con credenciales

**Flujo de Login**:
1. Usuario visita `/users/sign_in`
2. Ingresa email y contraseña
3. Devise autentica y crea sesión
4. Redirige a `root_path` (home)

**Helpers Disponibles**:
```ruby
user_signed_in?          # => true/false
current_user             # => User object o nil
authenticate_user!       # Fuerza login (before_action)
sign_out                 # Cierra sesión
```

---

### 9.2 Autorización (Custom)

**Implementación Manual** (sin gemas como Pundit o CanCanCan)

**Niveles de Acceso**:

1. **Propietario del Proyecto**
   - Puede ver, editar, eliminar
   - Puede gestionar gastos (crear, editar, eliminar)
   - Puede compartir con otros usuarios
   - Puede actualizar estados

2. **Usuario con Acceso Compartido**
   - Solo puede ver el proyecto
   - No puede editar ni eliminar
   - No puede gestionar gastos
   - No puede compartir con otros

**Implementación en Modelos**:

```ruby
# app/models/project.rb
class Project
  def can_access?(user)
    # Propietario o usuario compartido
    user == self.user || shared_with_users.include?(user)
  end

  def can_edit?(user)
    # Solo el propietario
    user == self.user
  end

  def shared_with?(user)
    # Verifica compartición
    shared_with_users.include?(user)
  end
end
```

**Implementación en Controladores**:

```ruby
# app/controllers/projects_controller.rb
class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  before_action :authorize_access, only: [:show]
  before_action :authorize_edit, only: [:edit, :update, :destroy]

  private

  def authorize_access
    unless @project.can_access?(current_user)
      redirect_to root_path, alert: 'No tienes acceso a este proyecto'
    end
  end

  def authorize_edit
    unless @project.can_edit?(current_user)
      redirect_to root_path, alert: 'No tienes permisos para editar'
    end
  end
end
```

**Flujo de Autorización**:

```
Usuario solicita ver proyecto
  ↓
¿Está autenticado? → NO → Redirige a login
  ↓ SÍ
¿Puede acceder? (can_access?) → NO → Redirige a home con error
  ↓ SÍ
Muestra proyecto con permisos limitados
  ↓
Si intenta editar:
  ↓
¿Puede editar? (can_edit?) → NO → Redirige a home con error
  ↓ SÍ
Permite edición
```

---

## 10. FRONTEND Y ASSETS

### 10.1 CSS Framework: Tailwind CSS

**Integración**: Gem `tailwindcss-rails`

**Archivo principal**: `app/assets/stylesheets/application.tailwind.css`

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Estilos personalizados */
@layer components {
  .btn-primary {
    @apply bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700;
  }

  .card {
    @apply bg-white rounded-lg shadow-md p-6;
  }
}
```

**Compilación**:
```bash
# Desarrollo (con watch)
bin/rails tailwindcss:watch

# Producción
bin/rails tailwindcss:build
```

**Clases más usadas**:
- Layout: `container`, `mx-auto`, `px-4`, `py-8`
- Grid: `grid`, `grid-cols-1`, `md:grid-cols-2`, `lg:grid-cols-3`, `gap-4`
- Flexbox: `flex`, `justify-between`, `items-center`, `space-x-4`
- Colores: `bg-white`, `text-gray-700`, `border-gray-300`
- Estados: `hover:bg-blue-700`, `focus:ring-2`

---

### 10.2 JavaScript

**Gestión de Módulos**: Importmap

**Archivo**: `config/importmap.rb`

```ruby
pin "application", preload: true
pin "@rails/ujs", to: "https://ga.jspm.io/npm:@rails/ujs@7.1.3/app/assets/javascripts/rails-ujs.esm.js"
```

**Bibliotecas Incluidas**:

1. **Rails UJS** (via Importmap)
   - Manejo de enlaces con `method: :delete`
   - Confirmaciones con `data-confirm`
   - AJAX requests

2. **Alpine.js v3** (via CDN)
   - Componentes interactivos ligeros
   - Modales
   - Toggles
   - Dropdowns

**Componentes JavaScript Personalizados**:

#### Búsqueda en Tiempo Real (home/index)

```javascript
function searchProjects() {
  const searchTerm = document.getElementById('search-input').value.toLowerCase();
  const projectCards = document.querySelectorAll('.project-card');

  projectCards.forEach(card => {
    const name = card.dataset.name.toLowerCase();
    const identifier = card.dataset.identifier.toLowerCase();

    if (name.includes(searchTerm) || identifier.includes(searchTerm)) {
      card.style.display = '';
    } else {
      card.style.display = 'none';
    }
  });
}
```

#### Formateo de Moneda

```javascript
function formatCurrency(input) {
  // Elimina caracteres no numéricos
  let value = input.value.replace(/[^\d]/g, '');

  // Formatea con puntos como separadores de miles
  value = value.replace(/\B(?=(\d{3})+(?!\d))/g, '.');

  input.value = value;
}
```

#### Modal con Alpine.js

```html
<div x-data="{ open: false }">
  <!-- Botón para abrir -->
  <button @click="open = true">Abrir Modal</button>

  <!-- Modal -->
  <div x-show="open"
       @click.away="open = false"
       class="fixed inset-0 bg-gray-600 bg-opacity-50">
    <div class="bg-white rounded-lg p-6">
      <!-- Contenido del modal -->
      <button @click="open = false">Cerrar</button>
    </div>
  </div>
</div>
```

#### Accordion para Tabla de Gastos

```html
<tr x-data="{ expanded: false }">
  <td @click="expanded = !expanded" class="cursor-pointer">
    <%= expense.description.truncate(50) %>
  </td>
  <!-- Más columnas -->
</tr>
<tr x-show="expanded" x-cloak>
  <td colspan="5">
    <!-- Detalles expandidos -->
    <div class="p-4 bg-gray-50">
      <p><strong>Descripción completa:</strong></p>
      <p><%= expense.description %></p>
    </div>
  </td>
</tr>
```

---

### 10.3 Assets Pipeline (Sprockets)

**Configuración**: `config/initializers/assets.rb`

```ruby
Rails.application.config.assets.version = "1.0"
Rails.application.config.assets.paths << Rails.root.join("node_modules")
```

**Precompilación en Producción**:
```bash
RAILS_ENV=production rails assets:precompile
```

**Assets Generados**:
- `application-[hash].css` (Tailwind compilado)
- `application-[hash].js` (importmap + UJS)

---

## 11. FLUJOS DE USUARIO

### 11.1 Flujo Completo: Crear Proyecto y Agregar Gastos

```
1. Usuario se registra
   POST /users → Crea cuenta
   ↓
2. Usuario inicia sesión
   POST /users/sign_in → Autentica
   ↓
3. Redirige a Home (/)
   GET / → Muestra lista vacía de proyectos
   ↓
4. Usuario hace clic en "Nuevo Proyecto"
   GET /projects/new → Formulario de creación
   ↓
5. Usuario completa formulario
   - Nombre: "Construcción Casa"
   - Orden: "OC-2025-001"
   - Valor: 50.000.000
   - Localidad: "Bogotá"
   ↓
6. Usuario envía formulario
   POST /projects → Crea proyecto con ID autogenerado (PROY-2025-001)
   ↓
7. Redirige a Home
   GET / → Muestra proyecto creado
   ↓
8. Usuario hace clic en el proyecto
   GET /projects/:id → Vista detallada
   ↓
9. Usuario completa formulario de gasto
   - Descripción: "Compra de cemento"
   - Monto: 500.000
   - Tipo: Ferretería
   - Fecha: 2025-12-10
   ↓
10. Usuario envía formulario
    POST /projects/:id/expenses → Crea gasto
    ↓
11. Redirige a proyecto actualizado
    GET /projects/:id → Muestra gasto agregado y saldo actualizado
    ↓
12. Usuario agrega más gastos (repite 9-11)
    ↓
13. Usuario comparte proyecto con colaborador
    - Abre modal "Compartir"
    - Ingresa email: colaborador@example.com
    - POST /projects/:id/shared_projects
    ↓
14. Colaborador inicia sesión
    GET / → Ve proyecto compartido en su home (solo lectura)
```

---

### 11.2 Flujo de Compartición de Proyectos

```
PROPIETARIO:
1. Abre proyecto (GET /projects/:id)
   ↓
2. Hace clic en "Compartir Proyecto"
   ↓
3. Abre modal con formulario
   ↓
4. Ingresa email del usuario: "maria@example.com"
   ↓
5. Envía formulario
   POST /projects/:id/shared_projects
   ↓
6. Sistema valida:
   - ¿Usuario existe? ✓
   - ¿No es el propietario? ✓
   - ¿No está ya compartido? ✓
   ↓
7. Crea SharedProject:
   - project_id: [id del proyecto]
   - user_id: [id de maria]
   - shared_by_id: [id del propietario]
   ↓
8. Redirige con mensaje de éxito

USUARIO COMPARTIDO (María):
1. Inicia sesión
   ↓
2. Ve home (GET /)
   ↓
3. Ve proyecto compartido en lista
   - Indicador visual de "Compartido"
   - No ve botones de editar/eliminar
   ↓
4. Hace clic en proyecto
   GET /projects/:id
   ↓
5. Ve detalles y gastos (SOLO LECTURA)
   - No ve botón "Editar"
   - No ve botón "Eliminar"
   - No ve formulario de gastos
   - No ve sección de compartir

REVOCAR ACCESO:
1. Propietario abre proyecto
   ↓
2. Ve lista de usuarios compartidos
   ↓
3. Hace clic en "Revocar acceso" de María
   DELETE /projects/:id/shared_projects/:shared_project_id
   ↓
4. Sistema elimina SharedProject
   ↓
5. María ya no ve el proyecto en su home
```

---

### 11.3 Flujo de Actualización de Estado

```
1. Usuario (propietario) abre home
   GET /
   ↓
2. Hace clic en badge de estado de ejecución (ej: "Pendiente")
   ↓
3. Abre modal de actualización de estado
   - Muestra select con opciones:
     * Pendiente
     * Ejecutando
     * Pausado
     * Cancelado
     * Terminado
   ↓
4. Usuario selecciona "Ejecutando"
   ↓
5. Envía formulario
   PATCH /projects/:id/update_status
   params: { execution_status: 'running' }
   ↓
6. Sistema actualiza estado
   @project.execution_status = 'running'
   @project.save
   ↓
7. Redirige a home con badge actualizado

CASO ESPECIAL: Estado "Terminado"
1. Usuario selecciona "Terminado"
   ↓
2. Aparece campo de fecha de liquidación
   (JavaScript muestra campo oculto)
   ↓
3. Usuario ingresa fecha: 2025-12-13
   ↓
4. Envía formulario
   PATCH /projects/:id/update_status
   params: {
     execution_status: 'ended',
     settlement_date: '2025-12-13'
   }
   ↓
5. Sistema actualiza:
   @project.execution_status = 'ended'
   @project.settlement_date = Date.parse('2025-12-13')
   @project.save
```

---

## 12. DEPLOYMENT

### 12.1 Infraestructura de Producción

**Servidor**:
- IP: 178.156.195.249
- Usuario: deploy
- Directorio: `/home/deploy/proytrack`

**Stack**:
- **Sistema Operativo**: Linux (Ubuntu/Debian)
- **Servidor Web**: NGINX (reverse proxy)
- **App Server**: Puma (vía systemd)
- **Base de Datos**: MongoDB (local, 127.0.0.1:27017)
- **Ruby**: 3.3.0 (via rbenv)
- **Node.js**: No requerido (Importmap)

---

### 12.2 Configuración de NGINX

**Archivo estimado**: `/etc/nginx/sites-available/proytrack`

```nginx
upstream puma_proytrack {
  server unix:///home/deploy/proytrack/tmp/sockets/puma.sock;
}

server {
  listen 80;
  server_name 178.156.195.249;  # o dominio

  root /home/deploy/proytrack/public;

  location / {
    try_files $uri @app;
  }

  location @app {
    proxy_pass http://puma_proytrack;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  # Assets estáticos
  location ~ ^/(assets|packs)/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}
```

---

### 12.3 Configuración de Systemd (Puma)

**Archivo estimado**: `/etc/systemd/system/puma.service`

```ini
[Unit]
Description=Puma HTTP Server for Proytrack
After=network.target mongod.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/home/deploy/proytrack
Environment=RAILS_ENV=production
Environment=RAILS_LOG_TO_STDOUT=true

ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C /home/deploy/proytrack/config/puma.rb
ExecReload=/bin/kill -SIGUSR1 $MAINPID

Restart=always
RestartSec=10

StandardOutput=append:/home/deploy/proytrack/log/puma.stdout.log
StandardError=append:/home/deploy/proytrack/log/puma.stderr.log

[Install]
WantedBy=multi-user.target
```

**Comandos de Gestión**:
```bash
# Iniciar
sudo systemctl start puma

# Detener
sudo systemctl stop puma

# Reiniciar
sudo systemctl restart puma

# Estado
sudo systemctl status puma

# Ver logs
sudo journalctl -u puma -f
```

---

### 12.4 CI/CD con GitHub Actions

**Archivo**: `.github/workflows/deploy.yml`

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.7.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Add server to known hosts
        run: |
          ssh-keyscan -H 178.156.195.249 >> ~/.ssh/known_hosts

      - name: Deploy to server
        run: |
          ssh deploy@178.156.195.249 << 'EOF'
            cd /home/deploy/proytrack

            # Pull latest code
            git fetch origin
            git reset --hard origin/main

            # Install dependencies
            bundle install --deployment --without development test

            # Run migrations (Mongoid)
            RAILS_ENV=production bundle exec rails db:mongoid:create_indexes

            # Precompile assets
            RAILS_ENV=production bundle exec rails assets:precompile

            # Restart services
            sudo systemctl restart puma
            sudo systemctl reload nginx

            echo "Deployment completed successfully!"
          EOF
```

**Secrets Necesarios** (GitHub Secrets):
- `SSH_PRIVATE_KEY`: Clave privada SSH para conectarse al servidor

**Flujo de Deployment**:
```
1. Developer hace push a main
   git push origin main
   ↓
2. GitHub Actions detecta push
   ↓
3. Ejecuta workflow:
   - Checkout del código
   - Configura SSH
   - Conecta al servidor
   ↓
4. En servidor:
   - git reset --hard origin/main (actualiza código)
   - bundle install (instala gemas)
   - rails db:mongoid:create_indexes (índices)
   - rails assets:precompile (compila CSS/JS)
   - systemctl restart puma (reinicia app)
   - systemctl reload nginx (recarga web server)
   ↓
5. Deployment exitoso
   App actualizada en producción
```

---

### 12.5 Configuración de MongoDB en Producción

**Instalación** (en servidor):
```bash
# Ubuntu/Debian
sudo apt-get install mongodb-org

# Iniciar servicio
sudo systemctl start mongod
sudo systemctl enable mongod
```

**Configuración** (`/etc/mongod.conf`):
```yaml
net:
  port: 27017
  bindIp: 127.0.0.1

security:
  authorization: enabled

storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
```

**Crear Usuario de Base de Datos**:
```javascript
// En mongo shell
use admin
db.createUser({
  user: "proytrack_user",
  pwd: "secure_password",
  roles: [
    { role: "readWrite", db: "proytrack_production" }
  ]
})
```

**Actualizar mongoid.yml** (si se usa autenticación):
```yaml
production:
  clients:
    default:
      database: proytrack_production
      hosts:
        - 127.0.0.1:27017
      options:
        user: proytrack_user
        password: <%= ENV['MONGODB_PASSWORD'] %>
        auth_source: admin
```

---

### 12.6 Variables de Entorno

**Archivo**: `.env` (en servidor)

```bash
# Producción
RAILS_ENV=production
RACK_ENV=production

# Secret Key Base
SECRET_KEY_BASE=<generado con rails secret>

# MongoDB (si usa autenticación)
MONGODB_PASSWORD=secure_password

# Puma
WEB_CONCURRENCY=2
RAILS_MAX_THREADS=5

# Logs
RAILS_LOG_TO_STDOUT=true
```

**Generar Secret Key**:
```bash
RAILS_ENV=production rails secret
# Copia el output a SECRET_KEY_BASE
```

---

### 12.7 Checklist de Deployment

**Antes del Deploy**:
- [ ] Tests pasan (actualmente no hay tests)
- [ ] Código revisado y aprobado
- [ ] Credenciales configuradas
- [ ] Variables de entorno definidas

**Durante el Deploy**:
- [ ] Backup de base de datos
- [ ] Pull del código
- [ ] Bundle install exitoso
- [ ] Assets precompilados
- [ ] Índices de MongoDB creados
- [ ] Puma reiniciado sin errores
- [ ] NGINX recargado

**Después del Deploy**:
- [ ] Verificar health check (`/up`)
- [ ] Verificar login funciona
- [ ] Verificar creación de proyecto
- [ ] Verificar logs sin errores
- [ ] Monitorear performance

---

## 13. GEMAS Y DEPENDENCIAS

### 13.1 Gemfile Completo

```ruby
source "https://rubygems.org"

ruby "3.3.0"

# Framework
gem "rails", "~> 7.1.5"

# Database
gem "mongoid"

# UI & Styling
gem "tailwindcss-rails"
gem "simple_enum", "~> 2.3.0"

# Authentication
gem "devise"

# Asset Pipeline
gem "sprockets-rails"
gem "importmap-rails"

# Server
gem "puma", ">= 5.0"

# Money handling
gem "money-rails"

# Configuration
gem "dotenv-rails", groups: [:development, :test]

# JSON rendering
gem "jbuilder"

# Timezone data (Windows)
gem "tzinfo-data", platforms: %i[windows jruby]

# Performance
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows]
end

group :development do
  gem "web-console"
end
```

### 13.2 Descripción de Gemas Principales

| Gema | Versión | Propósito |
|------|---------|-----------|
| rails | ~> 7.1.5 | Framework web principal |
| mongoid | latest | ODM para MongoDB |
| devise | latest | Autenticación de usuarios |
| tailwindcss-rails | latest | Framework CSS utilitario |
| simple_enum | ~> 2.3.0 | Enums con Mongoid |
| money-rails | latest | Manejo de monedas y valores monetarios |
| puma | >= 5.0 | Servidor de aplicaciones web |
| importmap-rails | latest | Gestión de módulos JavaScript |
| dotenv-rails | latest | Variables de entorno |
| jbuilder | latest | Constructor de JSON para APIs |

---

## 14. PATRONES Y BUENAS PRÁCTICAS

### 14.1 Patrones Implementados

#### MVC Clásico
```
Modelo (Model):
  - Define estructura de datos (Mongoid)
  - Contiene lógica de negocio
  - Validaciones
  - Relaciones entre entidades

Vista (View):
  - ERB templates
  - Presentación de datos
  - Formularios
  - Componentes reutilizables (partials)

Controlador (Controller):
  - Maneja requests HTTP
  - Orquesta interacción entre modelo y vista
  - Autorización y autenticación
  - Redirecciones y respuestas
```

#### Fat Models, Skinny Controllers
```ruby
# BIEN: Lógica en el modelo
class Project < ApplicationRecord
  def can_access?(user)
    user == self.user || shared_with_users.include?(user)
  end
end

class ProjectsController
  def show
    authorize_access  # Llama a método del modelo
  end
end

# MAL: Lógica en el controlador
class ProjectsController
  def show
    if @project.user != current_user &&
       !@project.shared_projects.pluck(:user_id).include?(current_user.id)
      redirect_to root_path
    end
  end
end
```

#### RESTful Routes
```ruby
# Recursos con acciones estándar
resources :projects, only: [:show, :new, :create, :edit, :update, :destroy]

# Recursos anidados
resources :projects do
  resources :expenses  # /projects/:project_id/expenses
end

# Rutas personalizadas como miembros
member do
  patch :update_status  # /projects/:id/update_status
end
```

---

### 14.2 Convenciones de Código

#### Nombres de Variables y Métodos
```ruby
# Snake case para variables y métodos
def generate_project_identifier
  project_identifier = "PROY-#{year}-#{number}"
end

# Métodos booleanos terminan en ?
def can_access?(user)
  # ...
end

# Métodos destructivos terminan en !
def normalize_email!
  self.email = email.downcase
end
```

#### Nombres de Clases y Módulos
```ruby
# PascalCase para clases
class ProjectsController < ApplicationController
end

class SharedProject
  include Mongoid::Document
end
```

#### Constantes
```ruby
# UPPER_SNAKE_CASE
MAX_UPLOAD_SIZE = 5.megabytes
DEFAULT_CURRENCY = 'COP'
```

---

### 14.3 Validaciones

#### En Modelos
```ruby
# Validaciones declarativas
validates :name, presence: true
validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :amount, numericality: { greater_than: 0 }

# Validaciones personalizadas
validate :cannot_share_with_self

private

def cannot_share_with_self
  if user_id == shared_by_id
    errors.add(:user_id, "no puede ser el mismo usuario")
  end
end
```

#### En Controladores
```ruby
# Strong parameters
def project_params
  params.require(:project).permit(:name, :purchase_order, :quoted_value)
end

# Autorización manual
before_action :authorize_access, only: [:show]

def authorize_access
  unless @project.can_access?(current_user)
    redirect_to root_path, alert: 'No autorizado'
  end
end
```

---

### 14.4 Callbacks

```ruby
# Before callbacks
before_validation :generate_project_identifier, on: :create
before_save :downcase_email

# After callbacks
after_create :send_welcome_email
after_destroy :cleanup_related_records

# Orden de ejecución:
# 1. before_validation
# 2. validate
# 3. after_validation
# 4. before_save
# 5. before_create (solo create)
# 6. INSERT/UPDATE en DB
# 7. after_create (solo create)
# 8. after_save
```

---

## 15. SEGURIDAD

### 15.1 Medidas de Seguridad Implementadas

#### CSRF Protection
```erb
<!-- Automático en layouts/application.html.erb -->
<%= csrf_meta_tags %>

<!-- Rails valida token CSRF en todos los POST/PATCH/DELETE -->
```

#### SQL Injection (N/A con MongoDB)
```ruby
# Mongoid usa queries parametrizadas
User.where(email: params[:email])  # Seguro
Project.in(id: shared_projects.pluck(:project_id))  # Seguro

# EVITAR:
# Project.where("user_id = #{params[:id]}")  # NO hacer esto
```

#### Password Hashing
```ruby
# Devise usa bcrypt automáticamente
user.encrypted_password  # => "$2a$12$K9..."
```

#### SSL/TLS en Producción
```ruby
# config/environments/production.rb
config.force_ssl = true
```

#### Content Security Policy
```ruby
# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.script_src  :self, :https, :unsafe_inline
  policy.style_src   :self, :https, :unsafe_inline
end
```

#### Mass Assignment Protection
```ruby
# Strong parameters previenen mass assignment
def project_params
  params.require(:project).permit(:name, :purchase_order)
  # Solo estos campos pueden ser asignados
end
```

---

### 15.2 Vulnerabilidades Potenciales

#### Credenciales Hardcodeadas
```yaml
# config/mongoid.yml
uri: mongodb+srv://jpcast:pro123@...  # ❌ MALO

# DEBERÍA SER:
uri: <%= ENV['MONGODB_URI'] %>  # ✅ MEJOR
```

#### Sin Rate Limiting
- No hay protección contra brute force en login
- No hay limitación de requests por IP

#### Sin Auditoría
- No hay registro de quién modificó qué
- No hay timestamps en SharedProject para saber cuándo se compartió

#### Email Validation Débil
```ruby
# Devise usa regex básico
# Podría aceptar emails inválidos
```

---

### 15.3 Recomendaciones de Seguridad

1. **Mover credenciales a variables de entorno**
   ```ruby
   # config/mongoid.yml
   production:
     clients:
       default:
         uri: <%= ENV['MONGODB_URI'] %>
   ```

2. **Implementar rate limiting**
   ```ruby
   # Gemfile
   gem 'rack-attack'

   # config/initializers/rack_attack.rb
   Rack::Attack.throttle('login', limit: 5, period: 60) do |req|
     req.ip if req.path == '/users/sign_in' && req.post?
   end
   ```

3. **Agregar auditoría**
   ```ruby
   # Gemfile
   gem 'mongoid-history'

   # Modelo
   include Mongoid::History::Trackable
   track_history on: [:name, :quoted_value],
                 modifier_field: :modified_by
   ```

4. **Validar emails con servicio externo**
   ```ruby
   # Gemfile
   gem 'email_validator'

   # Modelo
   validates :email, email: { mode: :strict }
   ```

5. **Implementar 2FA**
   ```ruby
   # Gemfile
   gem 'devise-two-factor'
   ```

---

## 16. PERFORMANCE Y OPTIMIZACIÓN

### 16.1 Consultas a Base de Datos

#### Consultas Actuales
```ruby
# Home#index
@projects = current_user.projects.to_a +
            current_user.shared_with_me_projects.to_a
# 2 queries + 1 query por proyecto para gastos

# Project#show
@expenses = @project.expenses.order(expense_date: :desc)
# 1 query

# SharedProject validations
shared_with_users.include?(user)
# 1 query por validación
```

#### Problema N+1
```ruby
# En home/index.html.erb
@projects.each do |project|
  project.expenses.sum(&:amount)  # N queries (1 por proyecto)
end
```

#### Solución con Eager Loading (Limitado en Mongoid)
```ruby
# Mongoid no soporta eager loading como ActiveRecord
# Alternativas:

# 1. Cachear valores calculados
field :total_expenses, type: Money, default: Money.new(0, 'COP')

after_save :update_project_totals, on: [:create, :update, :destroy]

def update_project_totals
  project.update(total_expenses: project.expenses.sum(&:amount))
end

# 2. Usar agregaciones de MongoDB
Project.collection.aggregate([
  { '$lookup' => {
      'from' => 'expenses',
      'localField' => '_id',
      'foreignField' => 'project_id',
      'as' => 'expenses'
    }
  },
  { '$addFields' => {
      'total_expenses' => { '$sum' => '$expenses.amount' }
    }
  }
])
```

---

### 16.2 Caching

#### Fragment Caching (No Implementado)
```erb
<!-- Cachear tarjetas de proyectos -->
<% @projects.each do |project| %>
  <% cache project do %>
    <%= render partial: 'project_card', locals: { project: project } %>
  <% end %>
<% end %>
```

#### Low-Level Caching
```ruby
# Cachear conteo de gastos
def expenses_count
  Rails.cache.fetch("project_#{id}_expenses_count", expires_in: 1.hour) do
    expenses.count
  end
end
```

#### Russian Doll Caching
```erb
<% cache ['projects', current_user.id, @projects.maximum(:updated_at)] do %>
  <% @projects.each do |project| %>
    <% cache project do %>
      <!-- contenido del proyecto -->
    <% end %>
  <% end %>
<% end %>
```

---

### 16.3 Índices de MongoDB

#### Índices Actuales
```ruby
# En modelos (inferidos del análisis)

# User
index({ email: 1 }, { unique: true })

# Project
index({ user_id: 1, project_identifier: 1 }, { unique: true })
index({ user_id: 1, created_at: -1 })

# Expense
index({ project_id: 1, expense_date: -1 })
index({ project_id: 1, expense_type: 1 })

# SharedProject
index({ project_id: 1, user_id: 1 }, { unique: true })
index({ user_id: 1, created_at: -1 })
```

#### Crear Índices
```bash
# Comando de Rails
RAILS_ENV=production rails db:mongoid:create_indexes

# Verificar índices en mongo shell
db.projects.getIndexes()
```

---

### 16.4 Asset Optimization

#### Tailwind CSS Purging
```ruby
# config/tailwind.config.js (si existe)
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

#### Compresión de Assets
```ruby
# config/environments/production.rb
config.assets.compress = true
config.assets.compile = false
config.assets.digest = true
```

---

## 17. TESTING (No Implementado)

### 17.1 Framework Recomendado

#### RSpec
```ruby
# Gemfile
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
end

group :test do
  gem 'mongoid-rspec'
  gem 'database_cleaner-mongoid'
  gem 'shoulda-matchers'
end
```

#### Setup
```bash
rails generate rspec:install
```

---

### 17.2 Ejemplos de Tests (Si Se Implementaran)

#### Model Specs

```ruby
# spec/models/project_spec.rb
require 'rails_helper'

RSpec.describe Project, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:purchase_order) }
    it { should validate_uniqueness_of(:project_identifier).scoped_to(:user_id) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:expenses) }
    it { should have_many(:shared_projects) }
  end

  describe '#can_access?' do
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }
    let(:project) { create(:project, user: owner) }

    context 'when user is owner' do
      it 'returns true' do
        expect(project.can_access?(owner)).to be true
      end
    end

    context 'when user is not owner and not shared' do
      it 'returns false' do
        expect(project.can_access?(other_user)).to be false
      end
    end

    context 'when project is shared with user' do
      before do
        create(:shared_project, project: project, user: other_user)
      end

      it 'returns true' do
        expect(project.can_access?(other_user)).to be true
      end
    end
  end

  describe '#generate_project_identifier' do
    let(:user) { create(:user) }

    it 'generates identifier with format PROY-YYYY-NNN' do
      project = build(:project, user: user)
      project.valid?
      expect(project.project_identifier).to match(/^PROY-\d{4}-\d{3}$/)
    end

    it 'increments number for subsequent projects' do
      first = create(:project, user: user)
      second = build(:project, user: user)
      second.valid?

      first_num = first.project_identifier.split('-').last.to_i
      second_num = second.project_identifier.split('-').last.to_i

      expect(second_num).to eq(first_num + 1)
    end
  end
end
```

#### Controller Specs

```ruby
# spec/controllers/projects_controller_spec.rb
require 'rails_helper'

RSpec.describe ProjectsController, type: :controller do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  before { sign_in user }

  describe 'GET #show' do
    context 'when user can access project' do
      it 'returns success response' do
        get :show, params: { id: project.id }
        expect(response).to be_successful
      end
    end

    context 'when user cannot access project' do
      let(:other_project) { create(:project) }

      it 'redirects to root with alert' do
        get :show, params: { id: other_project.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) {
      {
        project: {
          name: 'Test Project',
          purchase_order: 'PO-001',
          quoted_value: 1000000,
          locality: 'Bogotá'
        }
      }
    }

    context 'with valid params' do
      it 'creates a new project' do
        expect {
          post :create, params: valid_params
        }.to change(Project, :count).by(1)
      end

      it 'assigns current user as owner' do
        post :create, params: valid_params
        expect(Project.last.user).to eq(user)
      end

      it 'redirects to root with notice' do
        post :create, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to be_present
      end
    end

    context 'with invalid params' do
      let(:invalid_params) { { project: { name: '' } } }

      it 'does not create project' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Project, :count)
      end

      it 'renders new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end
  end
end
```

#### Feature Specs (Integration)

```ruby
# spec/features/project_management_spec.rb
require 'rails_helper'

RSpec.feature 'Project Management', type: :feature do
  let(:user) { create(:user, email: 'test@example.com', password: 'password') }

  before do
    visit new_user_session_path
    fill_in 'Email', with: 'test@example.com'
    fill_in 'Password', with: 'password'
    click_button 'Iniciar Sesión'
  end

  scenario 'User creates a new project' do
    click_link 'Nuevo Proyecto'

    fill_in 'Nombre del Proyecto', with: 'Construcción Casa'
    fill_in 'Orden de Compra', with: 'OC-2025-001'
    fill_in 'Valor Cotizado', with: '50000000'
    fill_in 'Localidad', with: 'Bogotá'

    click_button 'Crear Proyecto'

    expect(page).to have_content('Proyecto creado exitosamente')
    expect(page).to have_content('Construcción Casa')
    expect(page).to have_content('PROY-')
  end

  scenario 'User adds expense to project' do
    project = create(:project, user: user)

    visit project_path(project)

    fill_in 'Descripción', with: 'Compra de cemento'
    fill_in 'Monto', with: '500000'
    select 'Ferretería', from: 'Tipo'
    fill_in 'Fecha', with: Date.current

    click_button 'Agregar Gasto'

    expect(page).to have_content('Gasto agregado exitosamente')
    expect(page).to have_content('Compra de cemento')
    expect(page).to have_content('500.000')
  end

  scenario 'User shares project with another user' do
    project = create(:project, user: user)
    other_user = create(:user, email: 'collaborator@example.com')

    visit project_path(project)

    click_button 'Compartir Proyecto'

    within '#share-modal' do
      fill_in 'Email', with: 'collaborator@example.com'
      click_button 'Compartir'
    end

    expect(page).to have_content("Proyecto compartido con #{other_user.email}")
  end
end
```

#### Factories

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    password_confirmation { 'password123' }
  end
end

# spec/factories/projects.rb
FactoryBot.define do
  factory :project do
    association :user
    sequence(:name) { |n| "Project #{n}" }
    sequence(:purchase_order) { |n| "PO-#{n.to_s.rjust(3, '0')}" }
    quoted_value { Money.new(1000000, 'COP') }
    locality { 'Bogotá' }
    payment_status { :pending }
    execution_status { :pending }
  end
end

# spec/factories/expenses.rb
FactoryBot.define do
  factory :expense do
    association :project
    description { 'Test expense' }
    amount { Money.new(100000, 'COP') }
    expense_type { :payroll }
    expense_date { Date.current }
  end
end

# spec/factories/shared_projects.rb
FactoryBot.define do
  factory :shared_project do
    association :project
    association :user
    association :shared_by, factory: :user
  end
end
```

---

## 18. ERRORES COMUNES Y SOLUCIONES

### 18.1 Problemas de MongoDB

#### Error: Connection Timeout
```
Mongoid::Errors::NoClientHosts
```

**Solución**:
```bash
# Verificar que MongoDB esté corriendo
sudo systemctl status mongod

# Verificar configuración en mongoid.yml
# Asegurar que el host y puerto sean correctos
```

#### Error: Authentication Failed
```
Mongoid::Errors::InvalidSessionUse
```

**Solución**:
```yaml
# config/mongoid.yml
production:
  clients:
    default:
      options:
        user: <%= ENV['MONGODB_USER'] %>
        password: <%= ENV['MONGODB_PASSWORD'] %>
        auth_source: admin
```

---

### 18.2 Problemas de Devise

#### Error: Email Already Taken
```ruby
# En registro
errors.add(:email, "ya está en uso")
```

**Solución**:
Verificar unicidad en modelo:
```ruby
validates :email, uniqueness: { case_sensitive: false }
```

#### Error: Invalid Authentication Token
```
ActionController::InvalidAuthenticityToken
```

**Solución**:
Asegurar que el layout incluya:
```erb
<%= csrf_meta_tags %>
```

---

### 18.3 Problemas de Assets

#### Error: Assets Not Precompiled
```
ActionView::Template::Error: application.css isn't precompiled
```

**Solución**:
```bash
RAILS_ENV=production rails assets:precompile
```

#### Error: Tailwind Not Compiling
```
# CSS no se actualiza en desarrollo
```

**Solución**:
```bash
# Asegurar que el watcher esté corriendo
bin/rails tailwindcss:watch
```

---

## 19. MEJORAS FUTURAS RECOMENDADAS

### 19.1 Funcionalidades

1. **Reportes y Exportación**
   - Exportar proyectos a PDF
   - Exportar gastos a Excel
   - Gráficos de gastos por tipo
   - Dashboard con estadísticas

2. **Notificaciones**
   - Email cuando se comparte proyecto
   - Email cuando se agrega gasto
   - Recordatorios de proyectos pendientes

3. **Búsqueda Avanzada**
   - Filtros por estado
   - Filtros por rango de fechas
   - Filtros por rango de valores
   - Búsqueda full-text en descripciones

4. **Gestión de Usuarios**
   - Perfiles de usuario
   - Foto de perfil
   - Configuración de notificaciones
   - Historial de actividad

5. **Comentarios y Notas**
   - Comentarios en proyectos
   - Notas en gastos
   - Historial de cambios

---

### 19.2 Mejoras Técnicas

1. **Testing**
   - Implementar RSpec
   - Cobertura > 80%
   - Tests de integración
   - CI/CD con tests

2. **Performance**
   - Implementar caching
   - Optimizar queries
   - Lazy loading de imágenes
   - CDN para assets

3. **Seguridad**
   - Implementar rate limiting
   - 2FA opcional
   - Auditoría de cambios
   - Backup automático

4. **Monitoring**
   - New Relic o Datadog
   - Error tracking (Sentry)
   - Uptime monitoring
   - Performance metrics

5. **API**
   - API REST con autenticación
   - Documentación con Swagger
   - Rate limiting por API key
   - Versionado de API

---

## 20. CONCLUSIÓN

### 20.1 Resumen del Proyecto

Proytrack es una aplicación Rails 7.1 sólida y funcional para la gestión de proyectos y gastos. Utiliza tecnologías modernas como MongoDB, Tailwind CSS y Alpine.js para proporcionar una experiencia de usuario fluida y responsiva.

**Puntos Fuertes**:
- Arquitectura limpia y organizada
- Autenticación robusta con Devise
- Sistema de compartición flexible
- Interfaz moderna y responsiva
- Despliegue automatizado

**Áreas de Oportunidad**:
- Falta de tests automatizados
- Sin caching implementado
- Credenciales hardcodeadas
- Sin auditoría de cambios
- Performance mejorable

### 20.2 Estado del Proyecto

**Ambiente de Desarrollo**: ✅ Funcional
**Ambiente de Producción**: ✅ Desplegado
**Tests**: ❌ No implementados
**Documentación**: ✅ Buena (CLAUDE.md)
**Seguridad**: ⚠️ Básica, mejorable
**Performance**: ⚠️ Aceptable, optimizable

---

## 21. CONTACTO Y RECURSOS

### 21.1 Recursos del Proyecto

- **Repositorio**: (URL no especificada)
- **Servidor de Producción**: 178.156.195.249
- **Documentación**: CLAUDE.md en repositorio

### 21.2 Tecnologías Documentación

- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Mongoid Documentation](https://www.mongodb.com/docs/mongoid/)
- [Devise Documentation](https://github.com/heartcombo/devise)
- [Tailwind CSS Docs](https://tailwindcss.com/docs)
- [Alpine.js Docs](https://alpinejs.dev/)

---

**FIN DEL ANÁLISIS**

*Documento generado el 13 de diciembre de 2025*
