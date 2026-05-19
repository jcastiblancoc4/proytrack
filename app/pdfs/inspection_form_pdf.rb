require 'prawn'
require 'prawn/table'

class InspectionFormPdf
  LOGO_PATH   = Rails.root.join('app', 'assets', 'images', 'mc_ingenieros_logo.png').to_s
  FOOTER_TEXT = 'ESTE DOCUMENTO ES PARA USO EXCLUSIVO DE MC INGENIEROS SAS   ' \
                'SE PROHIBE SU REPRODUCCION TOTAL O PARCIAL.'

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
    pdf.move_down 20
    build_signature(pdf)
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
      { content: "CODIGO: #{@form.code}\nVERSION: #{@form.version}\nFECHA: #{date}", size: 9, valign: :center, padding: [6, 8, 6, 8] }
    ]]

    pdf.table(data, width: pdf.bounds.width) do |t|
      t.columns(0).width = 90
      t.columns(2).width = 130
      t.cells.border_width = 0.5
      t.cells.border_color = '000000'
    end
  end

  def build_info(pdf)
    fecha = @fr.inspection_datetime.strftime('%d/%m/%Y')
    hora  = @fr.inspection_datetime.strftime('%H:%M')
    w     = pdf.bounds.width
    half  = w / 2.0

    cell_style = { border_width: 0.5, border_color: '000000', padding: [4, 6, 4, 6], size: 9 }

    pdf.table([[{ content: "TEMA: #{@form.issue.upcase}" }]], width: w, cell_style: cell_style)
    pdf.table([[{ content: "OBJETIVO: #{@form.objective.upcase}" }]], width: w, cell_style: cell_style)

    pdf.table([
      [
        { content: "CLIENTE: #{@fr.cliente.to_s.upcase}" },
        { content: "PROYECTO: #{@fr.proyecto.to_s.upcase}" }
      ]
    ], width: w, cell_style: cell_style) do |t|
      t.columns(0).width = half
      t.columns(1).width = half
    end

    pdf.table([
      [
        { content: "CIUDAD: #{@fr.ciudad.to_s.upcase}" },
        { content: "RESPONSABLE: #{@fr.responsable.to_s.upcase}" }
      ]
    ], width: w, cell_style: cell_style) do |t|
      t.columns(0).width = half
      t.columns(1).width = half
    end

    pdf.table([
      [
        { content: "DILIGENCIADO POR: #{@fr.respondent_name.upcase}" },
        { content: "FECHA: #{fecha}    HORA: #{hora}" }
      ]
    ], width: w, cell_style: cell_style) do |t|
      t.columns(0).width = half
      t.columns(1).width = half
    end
  end

  def build_questions(pdf)
    w          = pdf.bounds.width
    cell_style = { border_width: 0.5, border_color: '000000' }

    @fr.responses.each_with_index do |resp, i|
      question_text = (resp.question_text.presence || resp.question&.question || 'Pregunta eliminada').upcase

      if resp.question&.options? || resp.question&.boxes?
        options  = resp.question.options? ? resp.question.options : resp.question.boxes
        selected = resp.question.options? ? [resp.string_answer.to_s] : Array(resp.array_answer)
        n        = options.size

        q_col_w  = (w * 0.40).round(1)
        opt_w    = ((w - q_col_w) / n.to_f).round(1)
        # ajuste de la última columna para cubrir exactamente el ancho total
        widths   = [q_col_w] + (n - 1).times.map { opt_w } + [w - q_col_w - opt_w * (n - 1)]

        # Fila 1: pregunta (rowspan 2) + etiqueta de cada opción
        row1 = [
          { content: "#{i + 1}. #{question_text}", font_style: :bold,
            background_color: 'EEEEEE', size: 9, padding: [5, 8, 5, 8],
            valign: :center, rowspan: 2 },
          *options.map { |opt|
            { content: opt.upcase, size: 9, align: :center, valign: :center,
              padding: [4, 4, 2, 4], background_color: 'EEEEEE' }
          }
        ]

        # Fila 2: X debajo de la(s) opción(es) seleccionada(s)
        row2 = options.map { |opt|
          selected.include?(opt) ?
            { content: 'X', size: 11, font_style: :bold, align: :center,
              valign: :center, padding: [2, 4, 4, 4] } :
            { content: '', padding: [2, 4, 4, 4] }
        }

        pdf.table([row1, row2], width: w, cell_style: cell_style) do |t|
          widths.each_with_index { |cw, j| t.columns(j).width = cw }
        end

      else
        answer = format_answer(resp)
        pdf.table(
          [
            [{ content: "#{i + 1}. #{question_text}", font_style: :bold,
               background_color: 'EEEEEE', size: 9, padding: [5, 8, 5, 8] }],
            [{ content: answer, size: 9, padding: [5, 8, 5, 8] }]
          ],
          width: w, cell_style: cell_style
        )
      end
    end
  end

  def format_answer(resp)
    if resp.string_answer.present?
      resp.string_answer.upcase
    elsif resp.array_answer.any?
      resp.array_answer.join(', ').upcase
    else
      '—'
    end
  end

  def build_signature(pdf)
    w         = pdf.bounds.width
    sig_width = w * 0.4
    sig_x     = (w - sig_width) / 2.0
    sig_path  = @fr.signature_path.present? ? Rails.root.join('public', @fr.signature_path).to_s : nil

    pdf.start_new_page if pdf.cursor < 110

    pdf.bounding_box([sig_x, pdf.cursor], width: sig_width) do
      pdf.text 'FIRMA DEL RESPONSABLE:', size: 9, style: :bold, align: :center
      pdf.move_down 6
      if sig_path && File.exist?(sig_path)
        pdf.image sig_path, fit: [sig_width - 16, 50], position: :center
        pdf.move_down 4
      else
        pdf.move_down 40
      end
      pdf.stroke { pdf.horizontal_rule }
      pdf.move_down 4
      pdf.text @fr.respondent_name.upcase, size: 9, align: :center
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
