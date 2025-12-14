class SettlementsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_settlement, only: [:show, :destroy]

  def index
    @settlements = Settlement.where(user: current_user).order(year: :desc, month: :desc)

    # Datos de preliquidación del mes actual
    @current_month = Date.current.month
    @current_year = Date.current.year

    start_date = Date.new(@current_year, @current_month, 1)
    end_date = Date.new(@current_year, @current_month, -1)

    # Proyectos terminados en el mes actual
    preliq_projects = Project.where(
      user: current_user,
      :settlement_date.gte => start_date,
      :settlement_date.lte => end_date,
      execution_status_cd: 4  # ended
    )

    # Gastos del mes actual en estado pending
    preliq_expenses = Expense.where(
      :expense_date.gte => start_date,
      :expense_date.lte => end_date,
      status_cd: 0  # pending
    ).includes(:project).select { |expense| expense.project.user == current_user }

    # Calcular totales de preliquidación
    @preliq_total_projects = preliq_projects.sum(&:quoted_value)
    @preliq_total_expenses = preliq_expenses.sum(&:amount)
    @preliq_difference = @preliq_total_projects - @preliq_total_expenses
    @preliq_projects_count = preliq_projects.count
    @preliq_expenses_count = preliq_expenses.count
    @month_name = I18n.l(Date.new(@current_year, @current_month, 1), format: '%B')
  end

  def preliquidation
    # Preliquidación del mes actual
    @current_month = Date.current.month
    @current_year = Date.current.year

    start_date = Date.new(@current_year, @current_month, 1)
    end_date = Date.new(@current_year, @current_month, -1)

    # Proyectos terminados en el mes actual
    @projects = Project.where(
      user: current_user,
      :settlement_date.gte => start_date,
      :settlement_date.lte => end_date,
      execution_status_cd: 4  # ended
    )

    # Gastos del mes actual en estado pending
    @expenses = Expense.where(
      :expense_date.gte => start_date,
      :expense_date.lte => end_date,
      status_cd: 0  # pending
    ).includes(:project).select { |expense| expense.project.user == current_user }

    # Calcular totales
    @total_projects_value = @projects.sum(&:quoted_value)
    @total_expenses_value = @expenses.sum(&:amount)
    @difference = @total_projects_value - @total_expenses_value

    @month_name = I18n.l(Date.new(@current_year, @current_month, 1), format: '%B')
  end

  def new
    @settlement = Settlement.new

    # Obtener meses disponibles para liquidar (meses con proyectos terminados)
    @available_months = get_available_months
  end

  def create
    @settlement = current_user.settlements.build(settlement_params)

    # Calcular totales
    start_date = Date.new(@settlement.year, @settlement.month, 1)
    end_date = Date.new(@settlement.year, @settlement.month, -1)

    # Proyectos terminados en el mes seleccionado
    projects = Project.where(
      user: current_user,
      :settlement_date.gte => start_date,
      :settlement_date.lte => end_date,
      execution_status_cd: 4  # ended
    )

    # Gastos del mes seleccionado en estado pending
    expenses = Expense.where(
      :expense_date.gte => start_date,
      :expense_date.lte => end_date,
      status_cd: 0  # pending
    ).includes(:project).select { |expense| expense.project.user == current_user }

    # Asignar totales
    @settlement.total_projects_value = projects.sum(&:quoted_value)
    @settlement.total_expenses_value = expenses.sum(&:amount)

    if projects.empty?
      redirect_to new_settlement_path, alert: 'No hay proyectos terminados en el mes seleccionado'
      return
    end

    if @settlement.save
      redirect_to settlements_path, notice: "Liquidación de #{@settlement.period_name} creada exitosamente"
    else
      @available_months = get_available_months
      render :new, status: :unprocessable_entity
    end
  end

  def show
    start_date = Date.new(@settlement.year, @settlement.month, 1)
    end_date = Date.new(@settlement.year, @settlement.month, -1)

    @projects = Project.where(
      user: current_user,
      :settlement_date.gte => start_date,
      :settlement_date.lte => end_date,
      execution_status_cd: 5  # in_liquidation
    )

    @expenses = @settlement.expenses.includes(:project)
  end

  def destroy
    @settlement.destroy
    redirect_to settlements_path, notice: 'Liquidación eliminada exitosamente'
  end

  private

  def set_settlement
    @settlement = Settlement.find(params[:id])
    unless @settlement.user == current_user
      redirect_to settlements_path, alert: 'No tienes acceso a esta liquidación'
    end
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to settlements_path, alert: 'Liquidación no encontrada'
  end

  def settlement_params
    params.require(:settlement).permit(:month, :year)
  end

  def get_available_months
    # Obtener proyectos terminados con settlement_date del usuario
    projects = Project.where(user: current_user, execution_status_cd: 4, :settlement_date.ne => nil)

    # Agrupar períodos por mes/año basándose en proyectos
    periods_hash = {}
    projects.each do |project|
      month = project.settlement_date.month
      year = project.settlement_date.year
      key = "#{year}-#{month}"

      periods_hash[key] = { month: month, year: year } unless periods_hash[key]
    end

    # También considerar gastos pendientes del usuario
    # (gastos que pertenecen a proyectos del usuario)
    user_project_ids = current_user.projects.pluck(:id)
    pending_expenses = Expense.where(
      :project_id.in => user_project_ids,
      status_cd: 0,  # pending
      :expense_date.ne => nil
    )

    pending_expenses.each do |expense|
      month = expense.expense_date.month
      year = expense.expense_date.year
      key = "#{year}-#{month}"

      periods_hash[key] = { month: month, year: year } unless periods_hash[key]
    end

    # Filtrar los que no tienen liquidación y formatear
    available = []
    periods_hash.each do |key, data|
      month = data[:month]
      year = data[:year]

      # Verificar si ya existe una liquidación para este período
      existing = Settlement.where(user: current_user, month: month, year: year).first

      unless existing
        month_name = I18n.l(Date.new(year, month, 1), format: '%B')
        available << { month: month, year: year, name: "#{month_name} #{year}" }
      end
    end

    # Ordenar por año y mes descendente (más reciente primero)
    available.sort_by { |p| [p[:year], p[:month]] }.reverse
  end
end
