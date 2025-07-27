class Project
  include Mongoid::Document
  include Mongoid::Timestamps
  include SimpleEnum::Mongoid

  field :name, type: String
  field :purchase_order, type: String
  field :quoted_value, type: Money, default: Money.new(0, 'COP')
  field :locality, type: String

  belongs_to :user
  has_many :expenses, dependent: :destroy

  as_enum :payment_status, {
    pending: 0,      # pendiente
    paid: 1,   # pagado
  }, field: { type: Integer, default: 0 }

  as_enum :execution_status, {
    pending: 0,      # pendiente
    running: 1,   # ejecutando
    stop: 2,      # pausado
    cancelled: 3, # cancelado
    ended: 4, # termino
  }, field: { type: Integer, default: 0 }
end
