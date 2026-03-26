class FormResponse
  include Mongoid::Document
  include Mongoid::Timestamps

  field :inspection_datetime, type: DateTime
  field :form_version,        type: Integer

  belongs_to :inspection_form
  belongs_to :user
  has_many :responses, dependent: :destroy

  before_validation :set_inspection_datetime, on: :create

  validates :inspection_form, presence: { message: "El formulario es obligatorio" }
  validates :user,            presence: { message: "El usuario es obligatorio" }

  def current_version?
    form_version == inspection_form&.version
  end

  def respondent_name
    profile = user&.profile
    profile ? profile.full_name : user&.email&.split("@")&.first
  end

  private

  def set_inspection_datetime
    self.inspection_datetime ||= Time.current
  end
end
