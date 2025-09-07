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

  # Validaciones
  validates :name, presence: { message: "El nombre del proyecto es obligatorio" }
  validates :project_identifier, presence: { message: "El identificador del proyecto es obligatorio" }
  validates :project_identifier, uniqueness: { 
    case_sensitive: false, 
    message: "El identificador del proyecto ya existe (no se distingue entre mayúsculas y minúsculas)" 
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
end
