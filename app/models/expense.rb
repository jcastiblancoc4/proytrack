class Expense
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :description, type: String
  field :amount, type: Money, default: Money.new(0, 'COP')
  field :expense_date, type: Date
  field :invoice_number, type: String

  belongs_to :project, optional: true
  belongs_to :user
  belongs_to :settlement, optional: true
  belongs_to :third_party, optional: true
  belongs_to :account, optional: true
  belongs_to :expense_category, optional: true

  has_one :account_transaction, class_name: 'Transaction', inverse_of: :expense, dependent: :destroy

  # Validaciones
  validates :description, presence: { message: "La descripción del gasto es obligatoria" }
  validates :amount, presence: { message: "El valor del gasto es obligatorio" }
  validates :expense_category, presence: { message: "El tipo de gasto es obligatorio" }
  #validates :expense_date, presence: { message: "La fecha del gasto es obligatoria" }

  validate :account_has_sufficient_funds, if: -> { new_record? && account_id.present? && amount.present? }

  # Enum original de tipos de gasto (reemplazado por el modelo ExpenseCategory)
  # as_enum :expense_type, {
  #   payroll: 0,
  #   hardware: 1,
  #   fuel: 2,
  # }, field: { type: Integer, default: 0 }

  as_enum :status, {
    pending: 0,
    in_liquidation: 1,
  }, field: { type: Integer, default: 0 }

  as_enum :support_type, {
    no_support: 0,
    electronic_invoice: 1,
    cash_receipt: 2,
    support_document: 3,
  }, field: { type: Integer, default: 0 }

  SUPPORT_TYPE_LABELS = {
    'no_support'         => 'Sin soporte',
    'electronic_invoice' => 'Factura electrónica',
    'cash_receipt'       => 'Recibo de caja',
    'support_document'   => 'Documento soporte'
  }.freeze

  def support_type_label
    SUPPORT_TYPE_LABELS[support_type.to_s] || 'Sin soporte'
  end

  before_save :clear_invoice_number_unless_electronic_invoice

  after_create  :create_account_transaction
  after_update  :sync_account_transaction_amount

  private

  def clear_invoice_number_unless_electronic_invoice
    self.invoice_number = nil if !electronic_invoice? && invoice_number.present?
  end

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

  def sync_account_transaction_amount
    return unless previous_changes.key?('amount') && account_transaction.present?
    account_transaction.update!(amount: amount)
  end

  def create_account_transaction
    return unless account_id.present?

    account_transaction.nil? && Transaction.create!(
      account:          account,
      expense:          self,
      transaction_type: :expense,
      amount:           amount,
      description:      description,
      transaction_date: expense_date || Date.current
    )
  end
end