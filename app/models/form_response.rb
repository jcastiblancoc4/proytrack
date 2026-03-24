class FormResponse
  include Mongoid::Document
  include Mongoid::Timestamps

  field :inspection_datetime, type: DateTime

  belongs_to :inspection_form
  belongs_to :responsible, class_name: 'ThirdParty'
  has_many :responses, dependent: :destroy

  before_validation :set_inspection_datetime, on: :create

  validates :inspection_form, presence: { message: "El formulario es obligatorio" }
  validates :responsible,     presence: { message: "El responsable es obligatorio" }

  private

  def set_inspection_datetime
    self.inspection_datetime ||= Time.current
  end
end
