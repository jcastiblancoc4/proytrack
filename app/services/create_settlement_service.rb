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

    # Ejecutar dentro de una transacción para garantizar atomicidad
    Settlement.with_session do |session|
      session.with_transaction do
        # Verificar si ya existe una liquidación
        existing_settlement = find_existing_settlement

        if existing_settlement
          update_existing_settlement(existing_settlement)
        else
          create_new_settlement
        end
      end
    end
  rescue => e
    failure("Error al crear la liquidación: #{e.message}")
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

  def pending_expenses
    @pending_expenses ||= Expense.where(
      user: user,
      :expense_date.gte => start_date,
      :expense_date.lte => end_date,
      status_cd: 0  # pending
    )
  end

  def no_pending_items?
    pending_projects.empty? && pending_expenses.empty?
  end

  def find_existing_settlement
    Settlement.where(
      user: user,
      month: month,
      year: year
    ).first
  end

  def create_new_settlement
    @settlement = user.settlements.build(
      month: month,
      year: year,
      total_projects_value: pending_projects.sum(&:quoted_value),
      total_expenses_value: pending_expenses.sum(&:amount)
    )

    unless @settlement.save
      raise ActiveRecord::RecordInvalid, @settlement.errors.full_messages.join(', ')
    end

    associate_projects_and_expenses(@settlement)
    success("Liquidación de #{@settlement.period_name} creada exitosamente con #{pending_projects.count} proyecto(s) y #{pending_expenses.count} gasto(s)")
  end

  def update_existing_settlement(existing_settlement)
    @settlement = existing_settlement

    # Asociar proyectos y gastos pendientes
    associate_projects_and_expenses(@settlement)

    # Recalcular totales
    @settlement.update!(
      total_projects_value: @settlement.projects.sum(&:quoted_value),
      total_expenses_value: @settlement.expenses.sum(&:amount)
    )

    success("Liquidación actualizada: #{pending_projects.count} proyecto(s) y #{pending_expenses.count} gasto(s) agregados")
  end

  def associate_projects_and_expenses(settlement)
    # Asociar proyectos a la liquidación y cambiar su estado
    pending_projects.each do |project|
      project.update!(execution_status_cd: 5, settlement: settlement)  # in_liquidation
    end

    # Asociar gastos a la liquidación y cambiar su estado
    pending_expenses.each do |expense|
      expense.update!(status_cd: 1, settlement: settlement)  # in_liquidation
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
