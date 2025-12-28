class Project
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :name, type: String
  field :project_identifier, type: String
  field :purchase_order, type: String
  field :quoted_value, type: Money, default: Money.new(0, 'COP')
  field :locality, type: String
  field :settlement_date, type: Date

  belongs_to :user
  belongs_to :settlement, optional: true
  has_many :expenses, dependent: :destroy
  has_many :shared_projects, dependent: :destroy

  # Callbacks
  before_validation :generate_project_identifier, on: :create

  # Validaciones
  validates :name, presence: { message: "El nombre del proyecto es obligatorio" }
  validates :project_identifier, presence: { message: "El identificador del proyecto es obligatorio" }
  validates :project_identifier, uniqueness: { 
    scope: :user_id,
    case_sensitive: false, 
    message: "El identificador del proyecto ya existe para este usuario (no se distingue entre mayúsculas y minúsculas)" 
  }
  validates :purchase_order, presence: { message: "La orden de compra es obligatoria" }
  validates :quoted_value, presence: { message: "El valor cotizado es obligatorio" }
  validates :locality, presence: { message: "La localidad es obligatoria" }

  as_enum :payment_status, {
    pending: 0,      # pendiente
    paid: 1,   # pagado
  }, field: { type: Integer, default: 0 }

  as_enum :execution_status, {
    pending: 0,      # pendiente
    running: 1,   # ejecutando
    stop: 2,      # pausado
    cancelled: 3, # cancelado
    ended: 4, # termino
    in_liquidation: 5, # en liquidación
  }, field: { type: Integer, default: 0 }

  # Métodos personalizados para usuarios compartidos (Mongoid no soporta through)
  def shared_with_users
    User.in(id: shared_projects.pluck(:user_id))
  end

  # Métodos para gestión de acceso
  def can_access?(user)
    user == self.user || shared_with_users.include?(user)
  end

  def can_edit?(user)
    # No se puede editar si está en liquidación
    # El método in_liquidation? es generado automáticamente por simple_enum
    return false if in_liquidation?
    user == self.user
  end

  def shared_with?(user)
    shared_with_users.include?(user)
  end

  private

  def generate_project_identifier
    return if project_identifier.present?
    
    # Generar un ID único basado en el año actual y un número secuencial
    current_year = Date.current.year
    last_project = user.projects.where(:project_identifier => /^PROY-#{current_year}-/).order(:project_identifier => :desc).first
    
    if last_project&.project_identifier
      # Extraer el número del último proyecto y incrementarlo
      last_number = last_project.project_identifier.split('-').last.to_i
      next_number = last_number + 1
    else
      # Primer proyecto del año
      next_number = 1
    end
    
    self.project_identifier = "PROY-#{current_year}-#{next_number.to_s.rjust(3, '0')}"
  end
end
