class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    # Incluir proyectos propios y proyectos compartidos
    own_projects = Project.where(user: current_user).to_a
    shared_projects = current_user.shared_with_me_projects.to_a
    
    @projects = (own_projects + shared_projects).sort_by do |project|
      last_expense_date = project.expenses.max_by(&:updated_at)&.updated_at
      [project.updated_at, last_expense_date].compact.max
    end.reverse
  end


end
