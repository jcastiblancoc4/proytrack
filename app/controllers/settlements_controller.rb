class SettlementsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_settlement, only: [:show, :update, :destroy]

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
      :project_id => preliq_projects.pluck(:id),
      status_cd: 0  # pending
    )

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
      user: current_user,
      :expense_date.gte => start_date,
      :expense_date.lte => end_date,
      status_cd: 0  # pending
    )

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
    service = CreateSettlementService.new(
      user: current_user,
      month: settlement_params[:month],
      year: settlement_params[:year]
    )

    result = service.call

    if result.success?
      @settlement = service.settlement

      # Redirigir según si fue actualización o creación nueva
      if service.message.include?('actualizada')
        redirect_to settlement_path(@settlement), notice: service.message
      else
        redirect_to settlements_path, notice: service.message
      end
    else
      @available_months = get_available_months
      redirect_to new_settlement_path, alert: service.errors.first
    end
  end

  def update
    # Actualizar liquidación existente con proyectos/gastos pendientes del período
    start_date = Date.new(@settlement.year, @settlement.month, 1)
    end_date = Date.new(@settlement.year, @settlement.month, -1)

    # Proyectos terminados pendientes del período
    pending_projects = Project.where(
      user: current_user,
      :settlement_date.gte => start_date,
      :settlement_date.lte => end_date,
      execution_status_cd: 4  # ended
    )

    # Gastos pendientes del período
    pending_expenses = Expense.where(
      user: current_user,
      :expense_date.gte => start_date,
      :expense_date.lte => end_date,
      status_cd: 0  # pending
    )

    if pending_projects.empty? && pending_expenses.empty?
      redirect_to settlements_path, alert: 'No hay proyectos ni gastos pendientes para liquidar en este período'
      return
    end

    # Actualizar proyectos a estado "en liquidación" y asociarlos
    pending_projects.each do |project|
      project.update(execution_status_cd: 5, settlement: @settlement)  # in_liquidation
    end

    # Actualizar gastos a estado "en liquidación" y asociarlos a la liquidación
    pending_expenses.each do |expense|
      expense.update(status_cd: 1, settlement: @settlement)  # in_liquidation
    end

    # Recalcular totales de la liquidación
    @settlement.update(
      total_projects_value: @settlement.projects.sum(&:quoted_value),
      total_expenses_value: @settlement.expenses.sum(&:amount)
    )

    redirect_to settlement_path(@settlement),
                notice: "Liquidación actualizada: #{pending_projects.count} proyecto(s) y #{pending_expenses.count} gasto(s) agregados"
  end

  def show
    @projects = @settlement.projects
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

      periods_hash[key] ||= { month: month, year: year, pending_projects: 0, pending_expenses: 0 }
      periods_hash[key][:pending_projects] += 1
    end

    # Obtener gastos pendientes que pertenezcan a proyectos con settlement_date
    pending_expenses = Expense.where(
      user: current_user,
      status_cd: 0  # pending
    ).includes(:project)

    # Agrupar gastos por el settlement_date del proyecto al que pertenecen
    pending_expenses.each do |expense|
      # Solo considerar gastos cuyo proyecto tenga settlement_date
      next unless expense.project&.settlement_date

      month = expense.project.settlement_date.month
      year = expense.project.settlement_date.year
      key = "#{year}-#{month}"

      periods_hash[key] ||= { month: month, year: year, pending_projects: 0, pending_expenses: 0 }
      periods_hash[key][:pending_expenses] += 1
    end

    # Formatear todos los períodos (con o sin liquidación)
    available = []
    periods_hash.each do |key, data|
      month = data[:month]
      year = data[:year]

      # Verificar si ya existe una liquidación para este período
      existing_settlement = Settlement.where(user: current_user, month: month, year: year).first

      # Solo incluir si hay items pendientes
      if data[:pending_projects] > 0 || data[:pending_expenses] > 0
        month_name = I18n.l(Date.new(year, month, 1), format: '%B')
        available << {
          month: month,
          year: year,
          name: "#{month_name} #{year}",
          has_settlement: existing_settlement.present?,
          settlement_id: existing_settlement&.id,
          pending_projects: data[:pending_projects],
          pending_expenses: data[:pending_expenses]
        }
      end
    end

    # Ordenar por año y mes descendente (más reciente primero)
    available.sort_by { |p| [p[:year], p[:month]] }.reverse
  end
end
