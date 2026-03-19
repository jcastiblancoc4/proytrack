class Account
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  BANKS = [
    "Bancolombia",
    "Banco de Bogotá",
    "Davivienda",
    "BBVA Colombia",
    "Banco de Occidente",
    "Banco Popular",
    "Banco Caja Social",
    "Colpatria",
    "Banco Agrario",
    "Nequi",
    "Daviplata",
    "Banco Falabella",
    "Banco Pichincha",
    "Banco Mundo Mujer",
    "Confiar Cooperativa Financiera"
  ].freeze

  field :name,           type: String
  field :account_number, type: String
  field :bank_name,      type: String
  field :balance,        type: Money, default: Money.new(0, 'COP')
  field :credit_limit,   type: Money, default: Money.new(0, 'COP')

  attr_accessor :initial_balance

  belongs_to :user
  has_many :transactions, dependent: :delete_all

  after_create :create_initial_transaction

  as_enum :account_type, {
    savings:  0,
    checking: 1,
    cash:     2,
    credit:   3
  }, field: { type: Integer, default: 0 }

  as_enum :credit_subtype, {
    credit_card: 0,
    revolving:   1
  }, field: { type: Integer, default: 0 }

  validates :name,           presence: { message: "El nombre de la cuenta es obligatorio" }
  validates :account_number, presence: { message: "El número de cuenta es obligatorio" },
                             if: :requires_bank?
  validates :account_type, presence: { message: "El tipo de cuenta es obligatorio" }
  validates :bank_name,
            presence: { message: "El banco es obligatorio" },
            if: :requires_bank?
  validates :credit_limit,
            presence: { message: "El cupo de crédito es obligatorio" },
            if: :credit?

  def requires_bank?
    savings? || checking? || credit?
  end

  def available_credit
    credit_limit - balance
  end

  private

  def create_initial_transaction
    amount = initial_balance.to_s.gsub(',', '.').to_f
    return unless amount > 0

    # Para crédito: el saldo inicial es deuda existente (egreso aumenta deuda)
    # Para cuentas normales: el saldo inicial es un ingreso
    tx_type = account_type.to_s == "credit" ? :expense : :income

    transactions.create!(
      transaction_type: tx_type,
      amount: Money.new(amount * 100, 'COP'),
      description: "Saldo inicial",
      transaction_date: Date.current
    )
  end
end
