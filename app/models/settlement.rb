class Settlement
  include Mongoid::Document
  include Mongoid::Timestamps

  field :month, type: Integer  # 1-12
  field :year, type: Integer
  field :total_projects_value, type: Money, default: Money.new(0, 'COP')
  field :total_expenses_value, type: Money, default: Money.new(0, 'COP')
  field :created_by_email, type: String  # Email del usuario que creó la liquidación

  belongs_to :user
  has_many :projects
  has_many :expenses
  has_many :shared_settlements, dependent: :destroy

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

  # Control de acceso
  def can_access?(user)
    # El propietario o usuarios con acceso compartido pueden ver
    user == self.user || shared_with_users.include?(user)
  end

  def can_edit?(user)
    # Solo el propietario puede editar
    user == self.user
  end

  def shared_with?(user)
    # Verifica si está compartido con un usuario específico
    shared_with_users.include?(user)
  end

  # Acceso a usuarios compartidos
  def shared_with_users
    User.in(id: shared_settlements.pluck(:user_id))
  end

  private

  def set_created_by_email
    self.created_by_email = user.email
  end

  def revert_related_statuses
    # Revertir proyectos a estado "ended" y quitar la asociación
    Project.where(settlement_id: self.id).each do |project|
      project.update(execution_status_cd: 4, settlement_id: nil)  # ended
    end

    # Revertir gastos a estado "pending" y quitar la asociación con settlement
    Expense.where(settlement_id: self.id).each do |expense|
      expense.update(status_cd: 0, settlement_id: nil)  # pending
    end
  end
end
