class InspectionForm
  include Mongoid::Document
  include Mongoid::Timestamps

  field :code,      type: String
  field :name,      type: String
  field :issue,     type: String
  field :objective, type: String
  field :version,   type: Integer, default: 1
  field :active,    type: Boolean, default: true

  belongs_to :user
  has_many :questions,       dependent: :destroy
  has_many :form_responses,  dependent: :destroy

  def current_questions
    questions.where(version: self.version).order(created_at: :asc)
  end

  def questions_for_version(v)
    questions.where(version: v).order(created_at: :asc)
  end

  def latest_version?
    InspectionForm.where(code: code).max(:version) == version
  end

before_validation :generate_code, on: :create

  validates :name,      presence: { message: "El nombre es obligatorio" }
  validates :issue,     presence: { message: "El asunto es obligatorio" }
  validates :objective, presence: { message: "El objetivo es obligatorio" }
  validates :code,      presence: true, uniqueness: { scope: :version, case_sensitive: false }

  private

  def generate_code
    return if code.present?
    # Solo buscar entre formularios originales (v1) para calcular el consecutivo
    last = InspectionForm.where(:code => /^MCOP-\d+$/, :version => 1).order(created_at: :desc).first
    seq = last ? last.code.split('-').last.to_i + 1 : 1
    self.code = "MCOP-#{seq}"
  end
end
