class PasswordChangesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    # update_with_password descarta la nueva contraseña si viene en blanco y
    # reporta éxito sin cambiar nada, así que se valida antes.
    if password_params[:password].blank?
      @user.errors.add(:password, :blank)
      return render :edit, status: :unprocessable_entity
    end

    if @user.update_with_password(password_params)
      # Devise invalida la sesión al cambiar la contraseña; se vuelve a
      # autenticar para que el usuario no tenga que iniciar sesión de nuevo.
      bypass_sign_in(@user)
      redirect_to root_path, notice: "Contraseña actualizada exitosamente."
    else
      @user.clean_up_passwords
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
