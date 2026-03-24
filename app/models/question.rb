class Question
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :question,          type: String
  field :written_response,  type: String
  field :options,           type: Array, default: []
  field :boxes,             type: Array, default: []

  as_enum :question_type, { written_response: 0, options: 1, boxes: 2 },
          field: { type: Integer, default: 0 }

  belongs_to :inspection_form
  has_many :responses, dependent: :destroy

  validates :question, presence: { message: "El texto de la pregunta es obligatorio" }
end
