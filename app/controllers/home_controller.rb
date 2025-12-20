class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    # Incluir proyectos propios y proyectos compartidos
    own_projects = Project.where(user: current_user).to_a
    shared_projects = current_user.shared_with_me_projects.to_a

    # Combinar proyectos
    all_projects = own_projects + shared_projects

    # Filtrar por estado de ejecución si se especificó
    # Ahora soporta múltiples estados
    if params[:execution_status].present?
      # Convertir a array si viene como string o ya es array
      selected_statuses = Array(params[:execution_status]).reject(&:blank?)

      # Filtrar solo si hay estados seleccionados y no incluye 'todos'
      if selected_statuses.any? && !selected_statuses.include?('todos')
        all_projects = all_projects.select { |project| selected_statuses.include?(project.execution_status.to_s) }
      end

      @selected_statuses = selected_statuses.include?('todos') ? ['todos'] : selected_statuses
    else
      @selected_statuses = ['todos']
    end

    # Ordenar por última actualización
    @projects = all_projects.sort_by do |project|
      last_expense_date = project.expenses.max_by(&:updated_at)&.updated_at
      [project.updated_at, last_expense_date].compact.max
    end.reverse
  end


end
