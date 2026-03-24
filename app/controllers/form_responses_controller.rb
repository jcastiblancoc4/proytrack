class FormResponsesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_inspection_form
  before_action :set_form_response, only: %i[show destroy]

  def index
    @form_responses = @inspection_form.form_responses.order(inspection_datetime: :desc)
  end

  def show
  end

  def new
    @form_response  = FormResponse.new
    @third_parties  = current_user.third_parties.order(first_name: :asc)
  end

  def create
    @form_response = FormResponse.new(
      inspection_form: @inspection_form,
      responsible_id:  params[:form_response][:responsible_id]
    )

    if @form_response.save
      build_responses(@form_response)
      redirect_to inspection_form_form_response_path(@inspection_form, @form_response),
                  notice: "Inspección registrada exitosamente."
    else
      @third_parties = current_user.third_parties.order(first_name: :asc)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @form_response.destroy
    redirect_to inspection_form_path(@inspection_form),
                notice: "Registro de inspección eliminado."
  end

  private

  def set_inspection_form
    @inspection_form = InspectionForm.find(params[:inspection_form_id])
    unless @inspection_form.user == current_user
      redirect_to inspection_forms_path, alert: "No tienes acceso a este formulario."
    end
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to inspection_forms_path, alert: "Formulario no encontrado."
  end

  def set_form_response
    @form_response = @inspection_form.form_responses.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to inspection_form_path(@inspection_form), alert: "Registro no encontrado."
  end

  def build_responses(form_response)
    return unless params[:responses].present?
    params[:responses].each do |question_id, r|
      question = Question.find(question_id) rescue next
      Response.create!(
        question:      question,
        form_response: form_response,
        string_answer: r[:string_answer].presence,
        array_answer:  Array(r[:array_answer]).reject(&:blank?)
      )
    end
  end
end
