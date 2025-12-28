class Settlement
  include Mongoid::Document
  include Mongoid::Timestamps

  field :month, type: Integer  # 1-12
  field :year, type: Integer
  field :total_projects_value, type: Money, default: Money.new(0, 'COP')
  field :total_expenses_value, type: Money, default: Money.new(0, 'COP')
  field :created_by_email, type: String  # Email del usuario que creó la liquidación

  belongs_to :user
  has_many :projects, dependent: :nullify
  has_many :expenses, dependent: :nullify

  # Validaciones
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :year, presence: true
  validates :user, presence: true
  validates :month, uniqueness: { scope: :year, message: "Ya existe una liquidación para este mes y año" }

  # Callbacks
  before_create :set_created_by_email
  before_destroy :revert_related_statuses

  # Métodos personalizados
  def month_name
    I18n.l(Date.new(year, month, 1), format: '%B')
  end

  def period_name
    "#{month_name} #{year}"
  end

  def difference
    total_projects_value - total_expenses_value
  end

  private

  def set_created_by_email
    self.created_by_email = user.email
  end

  def revert_related_statuses
    # Revertir proyectos a estado "ended" y quitar la asociación
    projects.each do |project|
      project.update(execution_status_cd: 4, settlement: nil)  # ended
    end

    # Revertir gastos a estado "pending" y quitar la asociación con settlement
    expenses.each do |expense|
      expense.update(status_cd: 0, settlement: nil)  # pending
    end
  end
end
