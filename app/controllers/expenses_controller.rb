class ExpensesController < ApplicationController
  before_action :set_project
  before_action :set_expense, only: [:edit, :update, :destroy]
  before_action :check_edit_permission, only: [:new, :create, :edit, :update, :destroy]
  before_action :check_expense_liquidation_status, only: [:edit, :update, :destroy]

  def index
    @expenses = @project.expenses
  end

  def new
    @expense = @project.expenses.build
  end

  def create
    @expense = @project.expenses.build(expense_params)
    @expense.user = current_user
    if @expense.save
      # Redireccionar según el origen
      if params[:from] == 'home'
        redirect_to root_path, notice: "Gasto registrado exitosamente."
      else
        redirect_to project_path(@project), notice: "Gasto registrado exitosamente."
      end
    else
      render :new, alert: "No se pudo guardar el gasto."
    end
  end

  def edit
  end

  def update
    @expense.user = current_user if @expense.user.nil?
    if @expense.update(expense_params)
      # Redireccionar según el origen
      if params[:from] == 'home'
        redirect_to root_path, notice: "Gasto actualizado exitosamente."
      else
        redirect_to project_path(@project), notice: "Gasto actualizado exitosamente."
      end
    else
      render :edit, alert: "No se pudo actualizar el gasto."
    end
  end

  def destroy
    @expense.destroy
    redirect_to project_path(@project), notice: "Gasto eliminado exitosamente."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_expense
    @expense = @project.expenses.find(params[:id])
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
    params.require(:expense).permit(:description, :amount, :expense_type, :expense_date)
  end
end
