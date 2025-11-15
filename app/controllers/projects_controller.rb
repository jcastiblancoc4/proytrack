class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: %i[ show edit update destroy update_status ]

  # GET /projects or /projects.json
  def index
    # Incluir proyectos propios y proyectos compartidos
    @projects = current_user.projects + current_user.shared_with_me_projects
  end

  # GET /projects/1 or /projects/1.json
  def show
    # Verificar que el usuario tenga acceso al proyecto
    unless @project.can_access?(current_user)
      flash[:alert] = "No tienes acceso a este proyecto"
      redirect_to root_path and return
    end
    
    @expenses = @project.expenses.order(created_at: :desc)
    @can_edit = @project.can_edit?(current_user)
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
    # Solo el propietario puede editar
    unless @project.can_edit?(current_user)
      flash[:alert] = "No tienes permisos para editar este proyecto"
      redirect_to project_path(@project) and return
    end
  end

  # POST /projects or /projects.json
  def create
    
    @project = Project.new(project_params)
    @project.user = current_user
    respond_to do |format|
      if @project.save
        format.html { redirect_to root_path, notice: "El proyecto fue creado exitosamente." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    # Solo el propietario puede actualizar
    unless @project.can_edit?(current_user)
      flash[:alert] = "No tienes permisos para editar este proyecto"
      redirect_to project_path(@project) and return
    end

    respond_to do |format|
      if @project.update(project_params)
        # Redireccionar según el origen
        if params[:from] == 'home'
          format.html { redirect_to root_path, notice: "Proyecto actualizado exitosamente." }
        else
          format.html { redirect_to project_path(@project), notice: "Proyecto actualizado exitosamente." }
        end
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    # Solo el propietario puede eliminar
    unless @project.can_edit?(current_user)
      flash[:alert] = "No tienes permisos para eliminar este proyecto"
      redirect_to project_path(@project) and return
    end

    @project.destroy!

    respond_to do |format|
      format.html { redirect_to root_path, status: :see_other, notice: "El proyecto fue eliminado con éxito." }
      format.json { head :no_content }
    end
  end

  # PATCH /projects/1/update_status
  def update_status
    # Solo el propietario puede actualizar el estado
    unless @project.can_edit?(current_user)
      flash[:alert] = "No tienes permisos para actualizar el estado de este proyecto"
      redirect_to project_path(@project) and return
    end

    new_status = params.dig(:project, :execution_status) || params[:execution_status]
    settlement_date = params.dig(:project, :settlement_date)

    # Preparar los atributos a actualizar
    update_attrs = { execution_status: new_status }

    # Si el estado es "ended" y se proporciona fecha de liquidación, agregarla
    if new_status == 'ended' && settlement_date.present?
      update_attrs[:settlement_date] = settlement_date
    elsif new_status != 'ended'
      # Si el estado NO es "ended", limpiar la fecha de liquidación
      update_attrs[:settlement_date] = nil
    end

    if new_status.present? && @project.update(update_attrs)
      flash[:notice] = "El estado del proyecto fue actualizado exitosamente."
      # Redireccionar según el origen (from parameter o referer)
      redirect_back(fallback_location: project_path(@project))
    else
      flash[:alert] = "Hubo un error al actualizar el estado del proyecto."
      redirect_back(fallback_location: project_path(@project))
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def project_params
      params.require(:project).permit(:name, :purchase_order, :quoted_value, :locality, :payment_status, :execution_status)
    end
end
