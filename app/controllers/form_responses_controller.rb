class FormResponsesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_inspection_form
  before_action :require_active_form!, only: [:new, :create]
  before_action :set_form_response, only: [:show]

  def show
  end

  def new
    @form_response = FormResponse.new
  end

  def create
    @form_response = FormResponse.new(
      inspection_form: @inspection_form,
      user:            current_user,
      form_version:    @inspection_form.version
    )

    if @form_response.save
      build_responses(@form_response)
      attach_pdf(@form_response)
      redirect_to inspection_form_form_response_path(@inspection_form, @form_response),
                  notice: "Inspección registrada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_inspection_form
    @inspection_form = InspectionForm.find(params[:inspection_form_id])
    allowed_owner = admin_user? ? current_user : current_user.owner
    unless @inspection_form.user == allowed_owner
      redirect_to inspection_forms_path, alert: "No tienes acceso a este formulario."
    end
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to inspection_forms_path, alert: "Formulario no encontrado."
  end

  def require_active_form!
    unless @inspection_form.active?
      redirect_to inspection_form_path(@inspection_form),
                  alert: "Este formulario está inactivo y no puede ser respondido."
    end
  end

  def set_form_response
    @form_response = @inspection_form.form_responses.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to inspection_form_path(@inspection_form), alert: "Registro no encontrado."
  end

  def attach_pdf(form_response)
    tempfile = InspectionFormPdf.generate_tempfile(form_response)
    relative_path = "uploads/form_responses/#{form_response.id}/inspeccion_#{form_response.id}.pdf"
    dest = Rails.root.join('public', relative_path)
    FileUtils.mkdir_p(dest.dirname)
    FileUtils.cp(tempfile.path, dest.to_s)
    form_response.update(pdf_report: relative_path)
  rescue => e
    Rails.logger.error "PDF generation failed for FormResponse #{form_response.id}: #{e.message}"
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def build_responses(form_response)
    return unless params[:responses].present?
    params[:responses].each do |question_id, r|
      question = Question.find(question_id) rescue next
      Response.create!(
        question:      question,
        question_text: question.question,
        form_response: form_response,
        string_answer: r[:string_answer].presence,
        array_answer:  Array(r[:array_answer]).reject(&:blank?)
      )
    end
  end
end
