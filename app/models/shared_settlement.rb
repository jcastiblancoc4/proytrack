class SharedSettlement
  include Mongoid::Document
  include Mongoid::Timestamps

  # Referencias a Settlement y User
  belongs_to :settlement
  belongs_to :user, inverse_of: :shared_settlements          # Usuario que recibe acceso
  belongs_to :shared_by, class_name: 'User', inverse_of: :shared_by_me_settlements  # Usuario que comparte

  # Validaciones
  validates :settlement_id, presence: true
  validates :user_id, presence: true,
                      uniqueness: { scope: :settlement_id, message: "ya tiene acceso a esta liquidación" }
  validates :shared_by_id, presence: true

  # Validación personalizada: no compartir consigo mismo
  validate :cannot_share_with_self

  # Validación personalizada: no compartir con el propietario
  validate :cannot_share_with_owner

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :for_settlement, ->(settlement) { where(settlement: settlement) }

  # Índices
  index({ settlement_id: 1, user_id: 1 }, { unique: true })
  index({ user_id: 1, created_at: -1 })
  index({ shared_by_id: 1, created_at: -1 })

  private

  def cannot_share_with_self
    if user_id == shared_by_id
      errors.add(:user_id, "no puede ser el mismo usuario que comparte")
    end
  end

  def cannot_share_with_owner
    if settlement && user_id == settlement.user_id
      errors.add(:user_id, "no puede ser el propietario de la liquidación")
    end
  end
end
