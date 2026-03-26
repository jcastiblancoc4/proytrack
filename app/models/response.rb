class Response
  include Mongoid::Document
  include Mongoid::Timestamps

  field :string_answer,  type: String
  field :array_answer,   type: Array, default: []
  field :question_text,  type: String

  belongs_to :question,      optional: true
  belongs_to :form_response

  validates :form_response, presence: { message: "La respuesta de formulario es obligatoria" }
end
