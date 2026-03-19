class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    # Proyectos activos (pendiente + ejecutando)
    @active_projects = current_user.projects
                                   .in(execution_status_cd: [0, 1])
                                   .order(updated_at: :desc)
                                   .limit(5)
    @active_projects_count = current_user.projects.in(execution_status_cd: [0, 1]).count
    @total_projects_count  = current_user.projects.count

    # Cuentas
    @accounts = current_user.accounts.order(created_at: :desc)
    @total_balance = @accounts.select { |a| a.account_type.to_s != "credit" }
                               .sum { |a| a.balance.to_i }

    # Últimos gastos
    @recent_expenses = current_user.expenses
                                   .order(expense_date: :desc, created_at: :desc)
                                   .limit(6)

    # Total gastos del mes actual
    @monthly_expenses_total = current_user.expenses
                                          .where(:expense_date.gte => Date.current.beginning_of_month,
                                                 :expense_date.lte => Date.current.end_of_month)
                                          .sum { |e| e.amount.to_i }

    # Preliquidación del mes actual
    start_date = Date.current.beginning_of_month
    end_date   = Date.current.end_of_month

    preliq_projects = Project.where(
      user: current_user,
      :settlement_date.gte => start_date,
      :settlement_date.lte => end_date,
      execution_status_cd: 4
    )
    preliq_expenses = Expense.where(
      user: current_user,
      :expense_date.gte => start_date,
      :expense_date.lte => end_date,
      status_cd: 0
    )
    @preliq_projects_value = preliq_projects.sum { |p| p.quoted_value.to_i }
    @preliq_expenses_value = preliq_expenses.sum { |e| e.amount.to_i }
    @preliq_difference     = @preliq_projects_value - @preliq_expenses_value
  end
end
