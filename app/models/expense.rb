class Expense
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :description, type: String
  field :amount, type: Money, default: Money.new(0, 'COP')
  field :expense_date, type: Date

  belongs_to :project, optional: true
  belongs_to :user
  belongs_to :settlement, optional: true
  belongs_to :third_party, optional: true
  belongs_to :account, optional: true

  has_one :account_transaction, class_name: 'Transaction', inverse_of: :expense, dependent: :destroy

  # Validaciones
  validates :description, presence: { message: "La descripción del gasto es obligatoria" }
  validates :amount, presence: { message: "El valor del gasto es obligatorio" }
  validates :expense_type, presence: { message: "El tipo de gasto es obligatorio" }
  #validates :expense_date, presence: { message: "La fecha del gasto es obligatoria" }

  as_enum :expense_type, {
    payroll: 0,
    hardware: 1,
    fuel: 2,
  }, field: { type: Integer, default: 0 }

  as_enum :status, {
    pending: 0,
    in_liquidation: 1,
  }, field: { type: Integer, default: 0 }

  after_create :create_account_transaction

  private

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