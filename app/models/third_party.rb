class ThirdParty
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  PERSON_DOCUMENT_TYPES = %w[cedula pasaporte nit].freeze
  COMPANY_DOCUMENT_TYPES = %w[nit].freeze

  as_enum :party_type, { person: 0, company: 1 }, field: { type: Integer, default: 0 }

  field :document_type,   type: String
  field :document_number, type: String
  field :phone,           type: String
  field :address,         type: String

  # Persona
  field :first_name, type: String
  field :last_name,  type: String

  # Empresa
  field :business_name, type: String

  belongs_to :user

  validates :party_type,     presence: { message: "El tipo de tercero es obligatorio" }
  validates :document_type,  presence: { message: "El tipo de documento es obligatorio" }
  validates :document_number, presence: { message: "El número de documento es obligatorio" }
  validates :phone,          presence: { message: "El número de contacto es obligatorio" }

  validates :first_name, presence: { message: "El nombre es obligatorio" }, if: :person?
  validates :last_name,  presence: { message: "El apellido es obligatorio" }, if: :person?
  validates :business_name, presence: { message: "La razón social es obligatoria" }, if: :company?

  validates :document_number,
            uniqueness: { scope: :user_id, message: "Ya existe un tercero con este número de documento" }

  def full_name
    person? ? "#{first_name} #{last_name}" : business_name
  end

  def document_type_label
    case document_type
    when "cedula"   then "Cédula"
    when "nit"      then "NIT"
    when "pasaporte" then "Pasaporte"
    else document_type
    end
  end
end