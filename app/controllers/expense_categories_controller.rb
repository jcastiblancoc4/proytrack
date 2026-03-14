class ExpenseCategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: [:update, :destroy]

  def create
    @category = ExpenseCategory.new(category_params)
    @category.user = current_user
    if @category.save
      redirect_to expenses_path, notice: "Tipo de gasto creado exitosamente."
    else
      redirect_to expenses_path, alert: @category.errors.full_messages.first
    end
  end

  def update
    if @category.update(category_params)
      redirect_to expenses_path, notice: "Tipo de gasto actualizado exitosamente."
    else
      redirect_to expenses_path, alert: @category.errors.full_messages.first
    end
  end

  def destroy
    if @category.in_use?
      redirect_to expenses_path, alert: "No se puede eliminar: el tipo está asociado a uno o más gastos.", status: :see_other
    else
      @category.destroy
      redirect_to expenses_path, notice: "Tipo de gasto eliminado exitosamente.", status: :see_other
    end
  end

  private

  def set_category
    @category = current_user.expense_categories.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to expenses_path, alert: "Tipo de gasto no encontrado."
  end

  def category_params
    params.require(:expense_category).permit(:name, :description)
  end
end