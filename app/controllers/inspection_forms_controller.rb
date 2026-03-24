class InspectionFormsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_form, only: %i[show edit update destroy]

  def index
    @inspection_forms = InspectionForm.where(user: current_user).order(created_at: :desc)
  end

  def show
  end

  def new
    @inspection_form = InspectionForm.new
  end

  def create
    @inspection_form = InspectionForm.new(form_params)
    @inspection_form.user = current_user

    if @inspection_form.save
      build_questions(@inspection_form)
      redirect_to @inspection_form, notice: "Formulario creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @inspection_form.update(form_params)
      @inspection_form.questions.destroy_all
      build_questions(@inspection_form)
      redirect_to @inspection_form, notice: "Formulario actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @inspection_form.destroy
    redirect_to inspection_forms_path, notice: "Formulario eliminado exitosamente."
  end

  private

  def set_form
    @inspection_form = InspectionForm.find(params[:id])
    unless @inspection_form.user == current_user
      flash[:alert] = "No tienes acceso a este formulario"
      redirect_to inspection_forms_path
    end
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to inspection_forms_path, alert: "Formulario no encontrado."
  end

  def form_params
    params.require(:inspection_form).permit(:name, :issue, :objective)
  end

  def build_questions(form)
    return unless params[:questions].present?
    params[:questions].each_value do |q|
      next if q[:question].blank?
      type_cd = q[:question_type_cd].to_i
      form.questions.create!(
        question:          q[:question],
        question_type_cd:  type_cd,
        written_response:  q[:written_response].presence,
        options:           (q[:options]&.reject(&:blank?) || []),
        boxes:             (q[:boxes]&.reject(&:blank?) || [])
      )
    end
  end
end
