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

    acct = account.reload

    if acct.account_type.to_s == "credit"
      disponible = acct.credit_limit - acct.balance
      if disponible.to_i < amount.to_i
        disponible_str = ActionController::Base.helpers.number_to_currency(
          disponible.to_i, unit: "$", separator: ",", delimiter: ".", precision: 0
        )
        errors.add(:base, "La tarjeta \"#{acct.name}\" no tiene cupo disponible suficiente. Disponible: #{disponible_str}")
      end
    else
      if acct.balance.to_i < amount.to_i
        saldo = ActionController::Base.helpers.number_to_currency(
          acct.balance.to_i, unit: "$", separator: ",", delimiter: ".", precision: 0
        )
        errors.add(:base, "La cuenta \"#{acct.name}\" no tiene fondos suficientes. Saldo disponible: #{saldo}")
      end
    end
  end

  def capture_old_amount
    return unless amount_changed?
    raw = amount_was
    @old_amount = raw.is_a?(Hash) ? Money.new(raw["cents"], raw["currency_iso"]) : raw
  end

  def adjust_balance_on_amount_change
    return unless @old_amount
    acct = account.reload
    if account.account_type.to_s == "credit"
      if transaction_type_cd == 1 # compra: sube deuda
        acct.set(balance: acct.balance - @old_amount + amount)
      else # pago: baja deuda
        acct.set(balance: acct.balance + @old_amount - amount)
      end
    else
      if transaction_type_cd == 1 # egreso
        acct.set(balance: acct.balance + @old_amount - amount)
      else
        acct.set(balance: acct.balance - @old_amount + amount)
      end
    end
  end

  def apply_to_balance
    acct = account.reload
    if account.account_type.to_s == "credit" # pago reduce deuda, compra aumenta deuda
      new_balance = income? ? acct.balance - amount : acct.balance + amount
    else
      new_balance = income? ? acct.balance + amount : acct.balance - amount
    end
    acct.set(balance: new_balance)
  end

  def revert_from_balance
    acct = account.reload
    if account.account_type.to_s == "credit"
      new_balance = income? ? acct.balance + amount : acct.balance - amount
    else
      new_balance = income? ? acct.balance - amount : acct.balance + amount
    end
    acct.set(balance: new_balance)
  end
end
