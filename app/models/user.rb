class User
  include Mongoid::Document
  include Mongoid::Timestamps

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ## Database authenticatable
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""

  # Normalizar email antes de guardar
  before_save :normalize_email

  private

  def normalize_email
    self.email = email.strip.downcase if email.present?
  end

  public

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  has_many :projects, dependent: :destroy
  has_many :shared_projects, dependent: :destroy, inverse_of: :user
  has_many :shared_by_me_projects, class_name: 'SharedProject', foreign_key: 'shared_by_id', inverse_of: :shared_by, dependent: :destroy

  # Métodos personalizados para proyectos compartidos (Mongoid no soporta through)
  def shared_with_me_projects
    Project.in(id: shared_projects.pluck(:project_id))
  end

  ## Trackable
  # field :sign_in_count,      type: Integer, default: 0
  # field :current_sign_in_at, type: Time
  # field :last_sign_in_at,    type: Time
  # field :current_sign_in_ip, type: String
  # field :last_sign_in_ip,    type: String

  ## Confirmable
  # field :confirmation_token,   type: String
  # field :confirmed_at,         type: Time
  # field :confirmation_sent_at, type: Time
  # field :unconfirmed_email,    type: String # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, type: Integer, default: 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token,    type: String # Only if unlock strategy is :email or :both
  # field :locked_at,       type: Time
end
