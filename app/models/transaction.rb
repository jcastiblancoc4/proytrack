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

  validate :account_has_sufficient_funds, if: -> { new_record? && transaction_type_cd == 1 && account.present? && amount.present? }

  after_create  :apply_to_balance
  after_destroy :revert_from_balance
  before_update :capture_old_amount
  after_update  :adjust_balance_on_amount_change

  private

  def account_has_sufficient_funds
    return unless account && amount

    balance = account.reload.balance

    if balance.to_i < amount.to_i
      saldo = ActionController::Base.helpers.number_to_currency(
        balance.to_i, unit: "$", separator: ",", delimiter: ".", precision: 0
      )
      errors.add(:base, "La cuenta \"#{account.name}\" no tiene fondos suficientes. Saldo disponible: #{saldo}")
    end
  end

  def capture_old_amount
    return unless amount_changed?
    raw = amount_was
    @old_amount = raw.is_a?(Hash) ? Money.new(raw["cents"], raw["currency_iso"]) : raw
  end

  def adjust_balance_on_amount_change
    return unless @old_amount
    account.reload
    if transaction_type_cd == 1 # expense
      account.set(balance: account.balance + @old_amount - amount)
    else
      account.set(balance: account.balance - @old_amount + amount)
    end
  end

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
