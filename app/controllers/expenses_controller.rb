class ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, if: -> { params[:project_id].present? }
  before_action :set_expense, only: [:edit, :update, :destroy]
  before_action :check_edit_permission, only: [:new, :create, :edit, :update, :destroy], if: -> { @project.present? }
  before_action :check_expense_liquidation_status, only: [:edit, :update, :destroy], if: -> { @project.present? }

  # Standalone index (no project context)
  def index
    @third_parties      = current_user.third_parties.order(:first_name.asc)
    @accounts           = current_user.accounts.order(created_at: :desc)
    @projects           = current_user.projects.in(execution_status_cd: [0, 1]).order(created_at: :desc)
    @all_projects       = current_user.projects.order(created_at: :desc)
    @expense_categories = current_user.expense_categories.order(name: :asc)

    @expenses        = apply_filters(current_user.expenses)
    @total_filtered  = @expenses.sum { |e| e.amount.to_i }
    @has_filters     = filters_active?
  end

  def export
    expenses = apply_filters(current_user.expenses)
    filename = "gastos_#{Date.current.strftime('%Y%m%d')}.xlsx"
    total    = expenses.sum { |e| e.amount.to_i }

    package = Axlsx::Package.new
    wb      = package.workbook

    wb.add_worksheet(name: "Gastos") do |sheet|
      # Estilos
      header_style = wb.styles.add_style(
        b: true,
        bg_color: "1D4ED8",
        fg_color: "FFFFFF",
        sz: 11,
        alignment: { horizontal: :center, vertical: :center, wrap_text: true },
        border: { style: :thin, color: "CCCCCC" }
      )
      cell_style = wb.styles.add_style(
        sz: 10,
        border: { style: :thin, color: "E5E7EB" }
      )
      total_label_style = wb.styles.add_style(
        b: true,
        sz: 10,
        alignment: { horizontal: :right },
        border: { style: :thin, color: "E5E7EB" }
      )
      total_value_style = wb.styles.add_style(
        b: true,
        sz: 10,
        num_fmt: 3,
        border: { style: :thin, color: "E5E7EB" }
      )

      # Encabezados en negrilla
      headers = ["Fecha", "Descripción", "Tipo de Gasto", "Proyecto", "Tercero", "Tipo Doc.", "Nº Documento", "Cuenta", "Valor (COP)"]
      sheet.add_row headers, style: header_style, height: 20

      # Filas de datos
      expenses.each do |e|
        sheet.add_row [
          e.expense_date&.strftime("%d/%m/%Y") || "-",
          e.description,
          e.expense_category&.name || "-",
          e.project&.project_identifier || "-",
          e.third_party&.full_name || "-",
          e.third_party&.document_type_label || "-",
          e.third_party&.document_number || "-",
          e.account&.name || "-",
          e.amount.to_i
        ], style: cell_style
      end

      # Fila de total
      sheet.add_row []
      sheet.add_row ["", "", "", "", "", "", "", "TOTAL", total],
                    style: [nil, nil, nil, nil, nil, nil, nil, total_label_style, total_value_style]

      # Ancho de columnas
      sheet.column_widths 14, 35, 18, 16, 22, 14, 16, 18, 16
    end

    send_data package.to_stream.read,
              filename: filename,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  def new
    @expense = @project.expenses.build
  end

  def create
    if @project.present?
      # Nested under project
      @expense = @project.expenses.build(expense_params)
      @expense.user = current_user
      if @expense.save
        if params[:from] == 'home'
          redirect_to root_path, notice: "Gasto registrado exitosamente."
        else
          redirect_to project_path(@project), notice: "Gasto registrado exitosamente."
        end
      else
        render :new, alert: "No se pudo guardar el gasto."
      end
    else
      # Standalone
      @expense = Expense.new(expense_params.except(:project_id))
      @expense.user = current_user

      project_id = expense_params[:project_id]
      if project_id.present?
        project = current_user.projects.find(project_id) rescue nil
        @expense.project = project
      end

      if @expense.save
        redirect_to expenses_path, notice: "Gasto registrado exitosamente."
      else
        @third_parties      = current_user.third_parties.order(:first_name.asc)
        @accounts           = current_user.accounts.order(created_at: :desc)
        @projects           = current_user.projects.in(execution_status_cd: [0, 1]).order(created_at: :desc)
        @all_projects       = current_user.projects.order(created_at: :desc)
        @expense_categories = current_user.expense_categories.order(name: :asc)
        @expenses           = apply_filters(current_user.expenses)
        @total_filtered     = @expenses.sum { |e| e.amount.to_i }
        @has_filters        = filters_active?
        render :index, status: :unprocessable_entity
      end
    end
  end

  def edit
    @expense_categories = current_user.expense_categories.order(name: :asc)
    unless @project.present?
      @third_parties = current_user.third_parties.order(:first_name.asc)
      @accounts      = current_user.accounts.order(created_at: :desc)
      @projects      = current_user.projects.in(execution_status_cd: [0, 1]).order(created_at: :desc)
    end
  end

  def update
    @expense.user = current_user if @expense.user.nil?
    if @expense.update(expense_params.except(:project_id))
      if @project.present?
        if params[:from] == 'home'
          redirect_to root_path, notice: "Gasto actualizado exitosamente."
        else
          redirect_to project_path(@project), notice: "Gasto actualizado exitosamente."
        end
      else
        redirect_to expenses_path, notice: "Gasto actualizado exitosamente."
      end
    else
      if @project.present?
        render :edit, alert: "No se pudo actualizar el gasto."
      else
        @third_parties = current_user.third_parties.order(:first_name.asc)
        @accounts = current_user.accounts.order(created_at: :desc)
        @projects = current_user.projects.in(execution_status_cd: [0, 1]).order(created_at: :desc)
        @expense_categories = current_user.expense_categories.order(name: :asc)
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @expense.destroy
    if @project.present?
      redirect_to project_path(@project), notice: "Gasto eliminado exitosamente."
    else
      redirect_to expenses_path, notice: "Gasto eliminado exitosamente.", status: :see_other
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_expense
    if @project.present?
      @expense = @project.expenses.find(params[:id])
    else
      @expense = current_user.expenses.find(params[:id])
    end
  rescue Mongoid::Errors::DocumentNotFound
    flash[:alert] = "No se encontró el gasto."
    redirect_to expenses_path
  end

  def check_edit_permission
    unless @project.can_edit?(current_user)
      if @project.in_liquidation?
        flash[:alert] = "No se pueden agregar, editar o eliminar gastos de un proyecto en liquidación."
      else
        flash[:alert] = "No tienes permisos para realizar esta acción. Solo el propietario del proyecto puede gestionar gastos."
      end
      redirect_to project_path(@project) and return
    end
  end

  def check_expense_liquidation_status
    if @expense && @expense.in_liquidation?
      flash[:alert] = "No se puede editar o eliminar un gasto que está en liquidación."
      redirect_to project_path(@project) and return
    end
  end

  def expense_params
    params.require(:expense).permit(:description, :amount, :expense_category_id, :expense_date, :project_id, :third_party_id, :account_id)
  end

  def apply_filters(scope)
    if params[:date_from].present?
      scope = scope.where(:expense_date.gte => Date.parse(params[:date_from]))
    end
    if params[:date_to].present?
      scope = scope.where(:expense_date.lte => Date.parse(params[:date_to]))
    end

    selected_project_ids = Array(params[:project_ids]).reject(&:blank?)
    scope = scope.in(project_id: selected_project_ids) if selected_project_ids.any?

    selected_category_ids = Array(params[:category_ids]).reject(&:blank?)
    scope = scope.in(expense_category_id: selected_category_ids) if selected_category_ids.any?

    selected_third_party_ids = Array(params[:third_party_ids]).reject(&:blank?)
    scope = scope.in(third_party_id: selected_third_party_ids) if selected_third_party_ids.any?

    selected_account_ids = Array(params[:account_ids]).reject(&:blank?)
    scope = scope.in(account_id: selected_account_ids) if selected_account_ids.any?

    scope.order(expense_date: :desc, created_at: :desc)
  end

  def filters_active?
    params[:date_from].present? || params[:date_to].present? ||
      Array(params[:project_ids]).reject(&:blank?).any? ||
      Array(params[:category_ids]).reject(&:blank?).any? ||
      Array(params[:third_party_ids]).reject(&:blank?).any? ||
      Array(params[:account_ids]).reject(&:blank?).any?
  end
end