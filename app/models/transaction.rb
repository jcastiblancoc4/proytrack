class Transaction
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :amount,           type: Money, default: Money.new(0, 'COP')
  field :description,      type: String
  field :transaction_date, type: Date

  belongs_to :account
  belongs_to :expense, optional: true

  as_enum :transaction_type, {
    income:  0,
    expense: 1
  }, field: { type: Integer, default: 0 }

  validates :amount,           presence: { message: "El valor de la transacción es obligatorio" }
  validates :transaction_type, presence: { message: "El tipo de transacción es obligatorio" }
  validates :description,      presence: { message: "La descripción es obligatoria" }
  validates :transaction_date, presence: { message: "La fecha es obligatoria" }

  after_create  :apply_to_balance
  after_destroy :revert_from_balance

  private

  def apply_to_balance
    account.reload
    new_balance = income? ? account.balance + amount : account.balance - amount
    account.set(balance: new_balance)
  end

  def revert_from_balance
    account.reload
    new_balance = income? ? account.balance - amount : account.balance + amount
    account.set(balance: new_balance)
  end
end
