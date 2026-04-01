class ManagedUsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_managed_user, only: [:edit, :update, :destroy]

  COLLABORATOR_LIMIT = 3

  def index
    @managed_users = current_user.managed_users.includes(:profile)
  end

  def new
    if collaborator_limit_reached?
      redirect_to managed_users_path, alert: "Has alcanzado el límite de #{COLLABORATOR_LIMIT} colaboradores permitidos."
      return
    end
    @managed_user = User.new
    @profile = UserProfile.new
  end

  def create
    if collaborator_limit_reached?
      redirect_to managed_users_path, alert: "Has alcanzado el límite de #{COLLABORATOR_LIMIT} colaboradores permitidos."
      return
    end

    @managed_user = User.new(user_params)
    @managed_user.owner_id = current_user.id
    @managed_user.role_cd = User.roles[:collaborator]
    @profile = @managed_user.build_profile(profile_params)

    if @managed_user.save
      redirect_to managed_users_path, notice: "Usuario creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @profile = @managed_user.profile || @managed_user.build_profile
  end

  def update
    @profile = @managed_user.profile || @managed_user.build_profile
    @profile.assign_attributes(profile_params)

    user_updated = user_update_params[:password].blank? ?
      @managed_user.update_without_password(user_update_params.except(:password, :password_confirmation)) :
      @managed_user.update(user_update_params)

    profile_saved = @profile.save

    if user_updated && profile_saved
      redirect_to managed_users_path, notice: "Usuario actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @managed_user.destroy
    redirect_to managed_users_path, notice: "Usuario eliminado exitosamente."
  end

  private

  def collaborator_limit_reached?
    current_user.managed_users.count >= COLLABORATOR_LIMIT
  end

  def set_managed_user
    @managed_user = current_user.managed_users.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to managed_users_path, alert: "Usuario no encontrado."
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def user_update_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def profile_params
    params.require(:user_profile).permit(:first_name, :last_name, :phone_number, :position_cd)
  end
end
