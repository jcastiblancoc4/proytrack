class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_project, only: %i[ show edit update destroy update_status ]

  # GET /projects or /projects.json
  def index
    own_projects = Project.where(user: current_user).to_a
    shared_projects = current_user.shared_with_me_projects.to_a
    all_projects = own_projects + shared_projects

    @total_projects = all_projects.count

    if params[:execution_status].present?
      selected_statuses = Array(params[:execution_status]).reject(&:blank?)
      if selected_statuses.any? && !selected_statuses.include?('todos')
        all_projects = all_projects.select { |project| selected_statuses.include?(project.execution_status.to_s) }
      end
      @selected_statuses = selected_statuses.include?('todos') ? ['todos'] : selected_statuses
    else
      @selected_statuses = ['todos']
    end

    @date_from = params[:date_from].present? ? (Date.parse(params[:date_from]) rescue nil) : nil
    @date_to   = params[:date_to].present?   ? (Date.parse(params[:date_to])   rescue nil) : nil

    all_projects = all_projects.select { |p| p.created_at.to_date >= @date_from } if @date_from
    all_projects = all_projects.select { |p| p.created_at.to_date <= @date_to   } if @date_to

    @sort_by        = %w[created_at updated_at].include?(params[:sort_by])        ? params[:sort_by]        : 'updated_at'
    @sort_direction = %w[asc desc].include?(params[:sort_direction]) ? params[:sort_direction] : 'desc'

    sorted = all_projects.sort_by do |project|
      if @sort_by == 'created_at'
        project.created_at
      else
        last_expense_date = project.expenses.max_by(&:updated_at)&.updated_at
        [project.updated_at, last_expense_date].compact.max
      end
    end

    @projects = @sort_direction == 'desc' ? sorted.reverse : sorted
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
    @can_share = @project.user == current_user
    @third_parties = current_user.third_parties.order(:first_name.asc)
    @accounts = current_user.accounts.order(created_at: :desc)
    @expense_categories = current_user.expense_categories.order(name: :asc)
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
    unless @project.user == current_user
      flash[:alert] = "No tienes permisos para actualizar el estado de este proyecto"
      redirect_to project_path(@project) and return
    end

    # No se puede actualizar el estado si está en liquidación
    if @project.in_liquidation?
      flash[:alert] = "No se puede modificar el estado de un proyecto en liquidación"
      redirect_to project_path(@project) and return
    end

    new_status = params.dig(:project, :execution_status) || params[:execution_status]
    settlement_date = params.dig(:project, :settlement_date)

    # Prevenir cambio manual a estado "en liquidación"
    if new_status == 'in_liquidation'
      flash[:alert] = "El estado 'En Liquidación' solo puede ser asignado automáticamente al crear una liquidación"
      redirect_to project_path(@project) and return
    end

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
