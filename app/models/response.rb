class Response
  include Mongoid::Document
  include Mongoid::Timestamps

  field :string_answer, type: String
  field :array_answer,  type: Array, default: []

  belongs_to :question
  belongs_to :form_response

  validates :question,      presence: { message: "La pregunta es obligatoria" }
  validates :form_response, presence: { message: "La respuesta de formulario es obligatoria" }
end
