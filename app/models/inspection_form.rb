class InspectionForm
  include Mongoid::Document
  include Mongoid::Timestamps

  field :code,      type: String
  field :name,      type: String
  field :issue,     type: String
  field :objective, type: String

  belongs_to :user
  has_many :questions,       dependent: :destroy
  has_many :form_responses,  dependent: :destroy

  before_validation :generate_code, on: :create

  validates :name,      presence: { message: "El nombre es obligatorio" }
  validates :issue,     presence: { message: "El asunto es obligatorio" }
  validates :objective, presence: { message: "El objetivo es obligatorio" }
  validates :code,      presence: true, uniqueness: { case_sensitive: false }

  private

  def generate_code
    return if code.present?
    year = Date.current.year
    last = InspectionForm.where(:code => /^FORM-#{year}-/).order(created_at: :desc).first
    seq = last ? last.code.split('-').last.to_i + 1 : 1
    self.code = "FORM-#{year}-#{seq.to_s.rjust(3, '0')}"
  end
end
