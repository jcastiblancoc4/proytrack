require 'prawn'
require 'prawn/table'

class InspectionFormPdf
  LOGO_PATH   = Rails.root.join('app', 'assets', 'images', 'mc_ingenieros_logo.png').to_s
  FOOTER_TEXT = 'Este documento es para uso exclusivo de MC INGENIEROS SAS   ' \
                'Se prohíbe su reproducción total o parcial.'

  def self.generate_tempfile(form_response)
    new(form_response).generate_tempfile
  end

  def initialize(form_response)
    @fr   = form_response
    @form = form_response.inspection_form
  end

  def generate_tempfile
    tempfile = Tempfile.new(["inspeccion_#{@fr.id}", '.pdf'])
    tempfile.binmode

    pdf = Prawn::Document.new(page_size: 'A4', margin: [30, 30, 55, 30])
    pdf.font_families.update('Helvetica' => { normal: 'Helvetica', bold: 'Helvetica-Bold', italic: 'Helvetica-Oblique', bold_italic: 'Helvetica-BoldOblique' })
    pdf.font 'Helvetica'

    build_header(pdf)
    build_info(pdf)
    pdf.move_down 6
    build_questions(pdf)
    build_footer(pdf)

    pdf.render_file(tempfile.path)
    tempfile.rewind
    tempfile
  end

  private

  def build_header(pdf)
    date = @fr.inspection_datetime.strftime('%Y-%m-%d')

    logo_cell = if File.exist?(LOGO_PATH)
      { image: LOGO_PATH, fit: [70, 50], position: :center, vposition: :center, padding: [6, 8, 6, 8] }
    else
      { content: 'MC', align: :center, font_style: :bold, valign: :center }
    end

    data = [[
      logo_cell,
      { content: @form.name.upcase, align: :center, font_style: :bold, size: 12, valign: :center, padding: [8, 6, 8, 6] },
      { content: "Codigo: #{@form.code}\nVersion: #{@form.version}\nFecha: #{date}", size: 9, valign: :center, padding: [6, 8, 6, 8] }
    ]]

    pdf.table(data, width: pdf.bounds.width) do |t|
      t.columns(0).width = 90
      t.columns(2).width = 130
      t.cells.border_width = 0.5
      t.cells.border_color = '000000'
    end
  end

  def build_info(pdf)
    fecha = @fr.inspection_datetime.strftime('%Y-%m-%d')
    hora  = @fr.inspection_datetime.strftime('%H:%M:%S')
    w     = pdf.bounds.width
    half  = w / 2.0

    cell_style = { border_width: 0.5, border_color: '000000', padding: [4, 6, 4, 6], size: 9 }

    # Tema
    pdf.table([[{ content: "Tema: #{@form.issue}" }]], width: w, cell_style: cell_style)

    # Objetivo
    pdf.table([[{ content: "Objetivo: #{@form.objective}" }]], width: w, cell_style: cell_style)

    # Responsable / Fecha — Lugar / Hora
    pdf.table([
      [
        { content: "Responsable: #{@fr.respondent_name}" },
        { content: "Fecha: #{fecha}" }
      ],
      [
        { content: 'Lugar:' },
        { content: "Hora: #{hora}" }
      ]
    ], width: w, cell_style: cell_style) do |t|
      t.columns(0).width = half
      t.columns(1).width = half
    end
  end

  def build_questions(pdf)
    w = pdf.bounds.width

    header = [
      { content: 'PREGUNTA',   font_style: :bold, align: :center, background_color: 'EEEEEE' },
      { content: 'RESPUESTA',  font_style: :bold, align: :center, background_color: 'EEEEEE' }
    ]

    rows = @fr.responses.map do |resp|
      question_text = resp.question_text.presence || resp.question&.question || 'Pregunta eliminada'
      [{ content: question_text }, { content: format_answer(resp) }]
    end

    data = [header] + rows

    pdf.table(data, width: w, cell_style: { border_width: 0.5, border_color: '000000', padding: [5, 6, 5, 6], size: 9 }) do |t|
      t.columns(0).width = w * 0.55
      t.columns(1).width = w * 0.45
      t.row(0).border_width = 0.5
    end
  end

  def format_answer(resp)
    if resp.string_answer.present?
      resp.string_answer
    elsif resp.array_answer.any?
      resp.array_answer.join(', ')
    else
      '—'
    end
  end

  def build_footer(pdf)
    pdf.go_to_page(pdf.page_count)
    pdf.bounding_box([0, pdf.bounds.absolute_bottom + 18], width: pdf.bounds.width) do
      pdf.stroke { pdf.horizontal_rule }
      pdf.move_down 4
      pdf.text FOOTER_TEXT, size: 7, align: :center, color: '555555'
    end
  end
end
