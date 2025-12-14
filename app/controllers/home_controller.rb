class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    # Incluir proyectos propios y proyectos compartidos
    own_projects = Project.where(user: current_user).to_a
    shared_projects = current_user.shared_with_me_projects.to_a

    # Combinar proyectos
    all_projects = own_projects + shared_projects

    # Filtrar por estado de ejecución si se especificó
    if params[:execution_status].present? && params[:execution_status] != 'todos'
      all_projects = all_projects.select { |project| project.execution_status.to_s == params[:execution_status] }
    end

    # Ordenar por última actualización
    @projects = all_projects.sort_by do |project|
      last_expense_date = project.expenses.max_by(&:updated_at)&.updated_at
      [project.updated_at, last_expense_date].compact.max
    end.reverse

    # Guardar el estado seleccionado para el filtro
    @selected_status = params[:execution_status] || 'todos'
  end


end
