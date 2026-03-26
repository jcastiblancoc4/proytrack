class ApplicationController < ActionController::Base
  helper_method :admin_user?, :collaborator_user?

  private

  def require_admin!
    return if admin_user?
    redirect_to inspection_forms_path, alert: "No tienes permiso para acceder a esta sección."
  end

  def admin_user?
    user_signed_in? && current_user.admin?
  end

  def collaborator_user?
    user_signed_in? && current_user.collaborator?
  end
end
