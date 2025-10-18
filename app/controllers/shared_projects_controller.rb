class SharedProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:create, :destroy]
  before_action :set_shared_project, only: [:destroy]

  def create
    # Validar que se proporcionó un email
    if params[:user_email].blank?
      flash[:alert] = "⚠️ Por favor ingresa un email válido"
      redirect_to project_path(@project) and return
    end

    # Buscar usuario por email (usar where.first en lugar de find_by para Mongoid)
    email_to_search = params[:user_email].strip.downcase
    @user_to_share = User.where(email: email_to_search).first

    if @user_to_share.nil?
      flash[:alert] = "❌ El usuario con email '#{params[:user_email]}' no existe en el sistema. Verifica que el email sea correcto o solicita al usuario que se registre primero."
      redirect_to project_path(@project) and return
    end

    # Validar que no sea el mismo propietario
    if @user_to_share.id == current_user.id
      flash[:alert] = "⚠️ No puedes compartir el proyecto contigo mismo"
      redirect_to project_path(@project) and return
    end

    # Validar que no esté ya compartido (usar where.first para Mongoid)
    existing_share = @project.shared_projects.where(user: @user_to_share).first
    if existing_share
      flash[:alert] = "ℹ️ El proyecto ya está compartido con #{@user_to_share.email}"
      redirect_to project_path(@project) and return
    end

    # Crear el shared_project
    @shared_project = @project.shared_projects.build(
      user: @user_to_share,
      shared_by: current_user
    )

    if @shared_project.save
      flash[:notice] = "✅ Proyecto compartido exitosamente con #{@user_to_share.email}"
    else
      flash[:alert] = "❌ Error: #{@shared_project.errors.full_messages.join(', ')}"
    end

    redirect_to project_path(@project)
  rescue StandardError => e
    Rails.logger.error "Error inesperado al compartir proyecto: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    flash[:alert] = "❌ Ocurrió un error inesperado. Por favor contacta al administrador."
    redirect_to project_path(@project)
  end

  def destroy
    if @shared_project.destroy
      flash[:notice] = "Acceso al proyecto revocado exitosamente"
    else
      flash[:alert] = "Error al revocar el acceso al proyecto"
    end

    redirect_to project_path(@project)
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  rescue Mongoid::Errors::DocumentNotFound
    flash[:alert] = "Proyecto no encontrado o no tienes permiso para acceder a él"
    redirect_to root_path
  end

  def set_shared_project
    @shared_project = @project.shared_projects.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    flash[:alert] = "Registro de compartir no encontrado"
    redirect_to project_path(@project)
  end

  def shared_project_params
    params.require(:shared_project).permit(:user_email)
  end
end
