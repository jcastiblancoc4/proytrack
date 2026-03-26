class UserProfile
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  belongs_to :user

  field :first_name,    type: String
  field :last_name,     type: String
  field :phone_number,  type: String

  as_enum :position, { inspector: 0, supervisor: 1 }, field: { type: Integer, default: 0 }

  validates :first_name,  presence: { message: "no puede estar en blanco" }
  validates :last_name,   presence: { message: "no puede estar en blanco" }
  validates :position,    presence: { message: "no puede estar en blanco" }

  def full_name
    "#{first_name} #{last_name}"
  end
end
