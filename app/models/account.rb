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

  attr_accessor :initial_balance

  belongs_to :user
  has_many :transactions, dependent: :delete_all

  after_create :create_initial_transaction

  as_enum :account_type, {
    savings:  0,
    checking: 1,
    cash:     2
  }, field: { type: Integer, default: 0 }

  validates :name,           presence: { message: "El nombre de la cuenta es obligatorio" }
  validates :account_number, presence: { message: "El número de cuenta es obligatorio" },
                             if: :requires_bank?
  validates :account_type, presence: { message: "El tipo de cuenta es obligatorio" }
  validates :bank_name,
            presence: { message: "El banco es obligatorio para cuentas de ahorro y corriente" },
            if: :requires_bank?

  def requires_bank?
    savings? || checking?
  end

  private

  def create_initial_transaction
    amount = initial_balance.to_s.gsub(',', '.').to_f
    return unless amount > 0

    transactions.create!(
      transaction_type: :income,
      amount: Money.new(amount * 100, 'COP'),
      description: "Saldo inicial",
      transaction_date: Date.current
    )
  end
end
