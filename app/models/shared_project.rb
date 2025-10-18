class SharedProject
  include Mongoid::Document
  include Mongoid::Timestamps

  # Relaciones
  belongs_to :project
  belongs_to :user, inverse_of: :shared_projects
  belongs_to :shared_by, class_name: 'User', inverse_of: :shared_by_me_projects
  
  # Validaciones
  validates :project_id, presence: true
  validates :user_id, presence: true
  validates :shared_by_id, presence: true
  
  # Validar que no se comparta el mismo proyecto con el mismo usuario dos veces
  validates :user_id, uniqueness: { scope: :project_id, message: "ya tiene acceso a este proyecto" }
  
  # Validar que el usuario no se comparta el proyecto a sí mismo
  validate :cannot_share_to_self
  validate :cannot_share_to_owner
  
  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :for_project, ->(project) { where(project: project) }
  
  private
  
  def cannot_share_to_self
    if user_id == shared_by_id
      errors.add(:user_id, "no puedes compartir el proyecto contigo mismo")
    end
  end
  
  def cannot_share_to_owner
    if project&.user_id == user_id
      errors.add(:user_id, "no puedes compartir el proyecto con su propietario")
    end
  end
end
