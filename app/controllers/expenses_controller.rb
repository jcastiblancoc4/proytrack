class ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, if: -> { params[:project_id].present? }
  before_action :set_expense, only: [:edit, :update, :destroy]
  before_action :check_edit_permission, only: [:new, :create, :edit, :update, :destroy], if: -> { @project.present? }
  before_action :check_expense_liquidation_status, only: [:edit, :update, :destroy], if: -> { @project.present? }

  # Standalone index (no project context)
  def index
    @expenses = current_user.expenses.order(created_at: :desc)
    @third_parties = current_user.third_parties.order(:first_name.asc)
    @accounts = current_user.accounts.order(created_at: :desc)
    @projects = current_user.projects.in(execution_status_cd: [0, 1]).order(created_at: :desc)
  end

  def new
    @expense = @project.expenses.build
  end

  def create
    if @project.present?
      # Nested under project
      @expense = @project.expenses.build(expense_params)
      @expense.user = current_user
      if @expense.save
        if params[:from] == 'home'
          redirect_to root_path, notice: "Gasto registrado exitosamente."
        else
          redirect_to project_path(@project), notice: "Gasto registrado exitosamente."
        end
      else
        render :new, alert: "No se pudo guardar el gasto."
      end
    else
      # Standalone
      @expense = Expense.new(expense_params.except(:project_id))
      @expense.user = current_user

      project_id = expense_params[:project_id]
      if project_id.present?
        project = current_user.projects.find(project_id) rescue nil
        @expense.project = project
      end

      if @expense.save
        redirect_to expenses_path, notice: "Gasto registrado exitosamente."
      else
        @third_parties = current_user.third_parties.order(:first_name.asc)
        @accounts = current_user.accounts.order(created_at: :desc)
        @projects = current_user.projects.in(execution_status_cd: [0, 1]).order(created_at: :desc)
        @expenses = current_user.expenses.order(created_at: :desc)
        render :index, status: :unprocessable_entity
      end
    end
  end

  def edit
    unless @project.present?
      @third_parties = current_user.third_parties.order(:first_name.asc)
      @accounts = current_user.accounts.order(created_at: :desc)
      @projects = current_user.projects.in(execution_status_cd: [0, 1]).order(created_at: :desc)
    end
  end

  def update
    @expense.user = current_user if @expense.user.nil?
    if @expense.update(expense_params.except(:project_id))
      if @project.present?
        if params[:from] == 'home'
          redirect_to root_path, notice: "Gasto actualizado exitosamente."
        else
          redirect_to project_path(@project), notice: "Gasto actualizado exitosamente."
        end
      else
        redirect_to expenses_path, notice: "Gasto actualizado exitosamente."
      end
    else
      if @project.present?
        render :edit, alert: "No se pudo actualizar el gasto."
      else
        @third_parties = current_user.third_parties.order(:first_name.asc)
        @accounts = current_user.accounts.order(created_at: :desc)
        @projects = current_user.projects.in(execution_status_cd: [0, 1]).order(created_at: :desc)
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @expense.destroy
    if @project.present?
      redirect_to project_path(@project), notice: "Gasto eliminado exitosamente."
    else
      redirect_to expenses_path, notice: "Gasto eliminado exitosamente.", status: :see_other
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_expense
    if @project.present?
      @expense = @project.expenses.find(params[:id])
    else
      @expense = current_user.expenses.find(params[:id])
    end
  rescue Mongoid::Errors::DocumentNotFound
    flash[:alert] = "No se encontró el gasto."
    redirect_to expenses_path
  end

  def check_edit_permission
    unless @project.can_edit?(current_user)
      if @project.in_liquidation?
        flash[:alert] = "No se pueden agregar, editar o eliminar gastos de un proyecto en liquidación."
      else
        flash[:alert] = "No tienes permisos para realizar esta acción. Solo el propietario del proyecto puede gestionar gastos."
      end
      redirect_to project_path(@project) and return
    end
  end

  def check_expense_liquidation_status
    if @expense && @expense.in_liquidation?
      flash[:alert] = "No se puede editar o eliminar un gasto que está en liquidación."
      redirect_to project_path(@project) and return
    end
  end

  def expense_params
    params.require(:expense).permit(:description, :amount, :expense_type, :expense_date, :project_id, :third_party_id, :account_id)
  end
end