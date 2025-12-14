class Expense
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :description, type: String
  field :amount, type: Money, default: Money.new(0, 'COP')
  field :expense_date, type: Date

  belongs_to :project
  belongs_to :settlement, optional: true

  # Validaciones
  validates :description, presence: { message: "La descripción del gasto es obligatoria" }
  validates :amount, presence: { message: "El valor del gasto es obligatorio" }
  validates :expense_type, presence: { message: "El tipo de gasto es obligatorio" }
  validates :expense_date, presence: { message: "La fecha del gasto es obligatoria" }

  as_enum :expense_type, {
    payroll: 0,
    hardware: 1,
    fuel: 2,
  }, field: { type: Integer, default: 0 }

  as_enum :status, {
    pending: 0,
    in_liquidation: 1,
  }, field: { type: Integer, default: 0 }

end