class AssetNovelty
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name,                  type: String
  field :date,                  type: Date
  field :description,           type: String
  field :responsible,           type: String
  field :signature_path,        type: String
  field :evidence_path,         type: String
  field :evidence_content_type, type: String

  belongs_to :fixed_asset

  validates :name,        presence: true
  validates :date,        presence: true
  validates :description, presence: true
  validates :responsible, presence: true

  ALLOWED_EVIDENCE_TYPES = %w[image/jpeg image/jpg image/png image/gif image/webp].freeze

  def signature_url
    signature_path.present? ? "/#{signature_path}" : nil
  end

  def evidence_url
    evidence_path.present? ? "/#{evidence_path}" : nil
  end

  def evidence_present?
    evidence_path.present?
  end

  def evidence_filename
    evidence_path&.split('/')&.last
  end
end
