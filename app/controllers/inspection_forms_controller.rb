class InspectionFormsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!, only: [:new, :create, :destroy, :new_version, :create_version]
  before_action :set_form, only: %i[show destroy new_version create_version versions]

  def index
    owner = admin_user? ? current_user : current_user.owner
    @inspection_forms = InspectionForm.where(user: owner, active: true).order(created_at: :desc)
  end

  def show
  end

  def versions
    @previous_versions = InspectionForm.where(code: @inspection_form.code, active: false)
                                       .order(version: :desc)
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

  def new_version
    @source_form = @inspection_form
    @next_version = InspectionForm.where(code: @source_form.code).max(:version) + 1
    @inspection_form = InspectionForm.new(
      name:      @source_form.name,
      issue:     @source_form.issue,
      objective: @source_form.objective
    )
    @prefill_questions = @source_form.current_questions.map do |q|
      { question: q.question, type: q.question_type_cd.to_s,
        written_response: q.written_response.to_s,
        options: q.options, boxes: q.boxes }
    end
  end

  def create_version
    source      = @inspection_form
    max_version = InspectionForm.where(code: source.code).max(:version)
    new_form    = InspectionForm.new(form_params)
    new_form.code    = source.code
    new_form.version = max_version + 1
    new_form.user    = current_user

    if new_form.save
      build_questions(new_form)
      InspectionForm.where(code: source.code, :id.ne => new_form.id).update_all(active: false)
      redirect_to new_form, notice: "Versión #{new_form.version} del formulario #{new_form.code} guardada exitosamente."
    else
      @source_form       = source
      @next_version      = max_version + 1
      @prefill_questions = []
      render :new_version, status: :unprocessable_entity
    end
  end

  def destroy
    if @inspection_form.form_responses.exists?
      redirect_to @inspection_form, alert: "No se puede eliminar el formulario porque tiene respuestas registradas."
      return
    end

    @inspection_form.destroy
    redirect_to inspection_forms_path, notice: "Formulario eliminado exitosamente."
  end

  private

  def set_form
    @inspection_form = InspectionForm.find(params[:id])
    allowed_owner = admin_user? ? current_user : current_user.owner
    unless @inspection_form.user == allowed_owner
      redirect_to inspection_forms_path, alert: "No tienes acceso a este formulario."
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
      form.questions.create!(question_attrs(q).merge(version: form.version))
    end
  end

  def sync_questions(form)
    if params[:questions].present?
      params[:questions].each_value do |q|
        next if q[:question].blank?

        if q[:id].present?
          existing = form.questions.find(q[:id]) rescue nil
          existing&.update(question_attrs(q))
        else
          form.questions.create!(question_attrs(q).merge(version: form.version + 1))
        end
      end
    end

    # Only delete questions explicitly removed in the editor
    removed_ids = Array(params[:removed_question_ids]).reject(&:blank?)
    removed_ids.each do |rid|
      q = form.questions.find(rid) rescue nil
      next unless q
      q.responses.update_all(question_id: nil) if q.responses.any?
      q.destroy
    end
  end

  def question_attrs(q)
    type_cd = q[:question_type_cd].to_i
    {
      question:         q[:question],
      question_type_cd: type_cd,
      written_response: q[:written_response].presence,
      options:          (q[:options]&.reject(&:blank?) || []),
      boxes:            (q[:boxes]&.reject(&:blank?) || [])
    }
  end
end
