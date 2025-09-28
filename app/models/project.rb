class Project
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :name, type: String
  field :project_identifier, type: String
  field :purchase_order, type: String
  field :quoted_value, type: Money, default: Money.new(0, 'COP')
  field :locality, type: String

  belongs_to :user
  has_many :expenses, dependent: :destroy

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
  }, field: { type: Integer, default: 0 }

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
