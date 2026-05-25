class FixedAsset
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :name,                    type: String
  field :serial,                  type: String
  field :purchase_date,           type: Date
  field :purchase_price,          type: Money, default: Money.new(0, 'COP')
  field :responsible,             type: String
  field :attachment_path,         type: String
  field :attachment_content_type, type: String
  field :assigned_to,             type: String
  field :assigned_date,           type: Date
  field :assigned_description,    type: String

  as_enum :status, {
    available:      0,
    assigned:       1,
    in_maintenance: 2,
    in_repair:      3,
    in_warehouse:   4,
    decommissioned: 6,
    lost_stolen:    7
  }, field: { type: Integer, default: 0 }

  belongs_to :user
  has_many :asset_novelties, dependent: :destroy

  validates :name,           presence: true
  validates :serial,         presence: true
  validates :purchase_date,  presence: true
  validates :purchase_price, presence: true
  validates :responsible,    presence: true
  validates :assigned_to,          presence: true, if: :assigned?
  validates :assigned_date,        presence: true, if: :assigned?
  validates :assigned_description, presence: true, if: :assigned?

  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/jpg image/png image/gif image/webp application/pdf].freeze

  STATUS_LABELS = {
    'available'      => 'Disponible',
    'assigned'       => 'Asignado',
    'in_maintenance' => 'En mantenimiento',
    'in_repair'      => 'En reparación',
    'in_warehouse'   => 'En bodega',
    'decommissioned' => 'Dado de baja',
    'lost_stolen'    => 'Perdido / Robado'
  }.freeze

  STATUS_COLORS = {
    'available'      => 'bg-green-100 text-green-800',
    'assigned'       => 'bg-blue-100 text-blue-800',
    'in_maintenance' => 'bg-amber-100 text-amber-800',
    'in_repair'      => 'bg-orange-100 text-orange-800',
    'in_warehouse'   => 'bg-purple-100 text-purple-800',
    'decommissioned' => 'bg-gray-100 text-gray-600',
    'lost_stolen'    => 'bg-red-100 text-red-800'
  }.freeze

  def attachment_url
    attachment_path.present? ? "/#{attachment_path}" : nil
  end

  def attachment_present?
    attachment_path.present?
  end

  def attachment_image?
    attachment_content_type&.start_with?('image/')
  end

  def attachment_filename
    attachment_path&.split('/')&.last
  end

  def status_label
    STATUS_LABELS[status.to_s] || status.to_s
  end

  def status_badge_class
    STATUS_COLORS[status.to_s] || 'bg-gray-100 text-gray-600'
  end
end
