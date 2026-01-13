class CreateSettlementService
  attr_reader :user, :month, :year, :settlement, :errors

  def initialize(user:, month:, year:)
    @user = user
    @month = month.to_i
    @year = year.to_i
    @errors = []
  end

  def call
    # Validar que hay proyectos o gastos pendientes
    return failure('No hay proyectos ni gastos pendientes para liquidar en el período seleccionado') if no_pending_items?

    begin
      # Verificar si ya existe una liquidación
      existing_settlement = find_existing_settlement

      if existing_settlement
        update_existing_settlement(existing_settlement)
      else
        create_new_settlement
      end
    rescue => e
      # Si hay error, revertir cambios manualmente si es necesario
      rollback_changes if @settlement
      failure("Error al crear la liquidación: #{e.message}")
    end
  end

  def success?
    @errors.empty?
  end

  def message
    @message
  end

  private

  def start_date
    @start_date ||= Date.new(year, month, 1)
  end

  def end_date
    @end_date ||= Date.new(year, month, -1)
  end

  def pending_projects
    @pending_projects ||= Project.where(
      user: user,
      :settlement_date.gte => start_date,
      :settlement_date.lte => end_date,
      execution_status_cd: 4  # ended
    )
  end

  def pending_expenses(projects:)
    @pending_expenses ||= Expense.where(
      user: user,
      status_cd: 0  # pending
    ).where(:project_id.in => projects.pluck(:id))
  end

  def no_pending_items?
    pending_projects.empty?
  end

  def find_existing_settlement
    Settlement.where(
      user: user,
      month: month,
      year: year
    ).first
  end

  def create_new_settlement
    # Capturar conteos ANTES de asociar (porque después cambiarán de estado)
    projects = pending_projects
    expenses = pending_expenses(projects: projects)
    @settlement = user.settlements.build(
      month: month,
      year: year,
      total_projects_value: projects.sum(&:quoted_value),
      total_expenses_value: expenses.sum(&:amount)
    )

    unless @settlement.save
      return failure(@settlement.errors.full_messages.join(', '))
    end

    unless associate_projects_and_expenses(@settlement)
      @settlement.destroy
      return failure("Error al asociar proyectos y gastos")
    end

    success("Liquidación de #{@settlement.period_name} creada exitosamente con #{projects.count} proyecto(s) y #{expenses.count} gasto(s)")
  end

  def update_existing_settlement(existing_settlement)
    @settlement = existing_settlement

    # Capturar conteos ANTES de asociar
    projects = pending_projects
    expenses = pending_expenses(projects: projects)

    # Asociar proyectos y gastos pendientes
    unless associate_projects_and_expenses(@settlement)
      return failure("Error al asociar proyectos y gastos")
    end

    # Recalcular totales
    unless @settlement.update(
      total_projects_value: @settlement.projects.sum(&:quoted_value),
      total_expenses_value: @settlement.expenses.sum(&:amount)
    )
      return failure("Error al actualizar totales de la liquidación")
    end

    success("Liquidación actualizada: #{projects_count} proyecto(s) y #{expenses_count} gasto(s) agregados")
  end

  def associate_projects_and_expenses(settlement)
    # Asociar proyectos a la liquidación y cambiar su estado
    projects = pending_projects
    projects.each do |project|
      p "project id: #{project.id.to_s}"
      unless project.update!(execution_status_cd: 5, settlement: settlement)  # in_liquidation
        return false
      end
    end

    # Asociar gastos a la liquidación y cambiar su estado
    pending_expenses(projects: projects).each do |expense|
      p "expense id: #{expense.id.to_s}"
      unless expense.update!(status_cd: 1, settlement: settlement)  # in_liquidation
        return false
      end
    end

    true
  end

  def rollback_changes
    # Revertir proyectos asociados a esta liquidación
    if @settlement && @settlement.persisted?
      Project.where(settlement_id: @settlement.id).each do |project|
        project.update(execution_status_cd: 4, settlement_id: nil)  # ended
      end

      # Revertir gastos asociados a esta liquidación
      Expense.where(settlement_id: @settlement.id).each do |expense|
        expense.update(status_cd: 0, settlement_id: nil)  # pending
      end

      # Eliminar la liquidación
      @settlement.destroy
    end
  end

  def success(message)
    @message = message
    self
  end

  def failure(error_message)
    @errors << error_message
    self
  end
end
