class Expense
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :description, type: String
  field :amount, type: Money, default: Money.new(0, 'COP')

  belongs_to :project

  as_enum :expense_type, {
    payroll: 0,
    hardware: 1,
    fuel: 2,
  }, field: { type: Integer, default: 0 }

end