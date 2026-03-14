class ExpenseCategory
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name,        type: String
  field :description, type: String

  belongs_to :user
  has_many :expenses, inverse_of: :expense_category

  validates :name, presence: { message: "El nombre es obligatorio" }
  validates :name, uniqueness: { scope: :user_id, message: "Ya existe un tipo con este nombre" }

  def in_use?
    expenses.exists?
  end
end