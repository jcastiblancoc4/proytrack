class Transaction
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :description, type: String
  field :amount, type: Money, default: Money.new(0, 'COP')
  field :transaction_date, type: Date

  belongs_to :project
  belongs_to :user
  belongs_to :settlement, optional: true

  # Validaciones
  validates :description, presence: { message: "La descripción de la transacción es obligatoria" }
  validates :amount, presence: { message: "El valor de la transacción es obligatorio" }
  validates :transaction_type, presence: { message: "El tipo de transacción es obligatorio" }
  validates :category, presence: { message: "La categoría es obligatoria" }

  # Enum para tipo de transacción
  as_enum :transaction_type, {
    debit: 0,    # Débito (egreso adicional)
    credit: 1,   # Crédito (ingreso adicional)
  }, field: { type: Integer, default: 0 }

  # Enum para categoría (mismo que expense_type en Expense)
  as_enum :category, {
    payroll: 0,
    hardware: 1,
    fuel: 2,
  }, field: { type: Integer, default: 0 }

  # Enum para estado
  as_enum :status, {
    pending: 0,
    in_liquidation: 1,
  }, field: { type: Integer, default: 0 }

  # Índices
  index({ project_id: 1, transaction_date: -1 })
  index({ user_id: 1, status_cd: 1 })
  index({ settlement_id: 1 })
end
