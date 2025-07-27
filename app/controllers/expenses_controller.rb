class ExpensesController < ApplicationController
  before_action :set_project
  before_action :set_expense, only: [:edit, :update, :destroy]

  def index
    @expenses = @project.expenses
  end

  def new
    @expense = @project.expenses.build
  end

  def create
    @expense = @project.expenses.build(expense_params)
    if @expense.save
      redirect_to root_path, notice: "Gasto registrado exitosamente."
    else
      render :new, alert: "No se pudo guardar el gasto."
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to root_path, notice: "Gasto actualizado exitosamente."
    else
      render :edit, alert: "No se pudo actualizar el gasto."
    end
  end

  def destroy
    @expense.destroy
    redirect_to root_path, notice: "Gasto eliminado exitosamente."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_expense
    @expense = @project.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:description, :amount, :expense_type)
  end
end
