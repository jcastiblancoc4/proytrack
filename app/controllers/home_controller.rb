class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    @projects = Project.where(user: current_user).to_a.sort_by do |project|
      last_expense_date = project.expenses.max_by(&:updated_at)&.updated_at
      [project.updated_at, last_expense_date].compact.max
    end.reverse
  end


end
