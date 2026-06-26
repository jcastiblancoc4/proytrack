require 'prawn'
require 'prawn/table'

class FixedAssetPdf
  LOGO_PATH   = Rails.root.join('app', 'assets', 'images', 'mc_ingenieros_logo.png').to_s
  FOOTER_TEXT = 'ESTE DOCUMENTO ES PARA USO EXCLUSIVO DE MC INGENIEROS SAS   ' \
                'SE PROHIBE SU REPRODUCCION TOTAL O PARCIAL.'

  PRIMARY  = '1B4F72'
  LABEL_BG = 'EBF5FB'
  HEADER_BG = 'D6EAF8'
  BORDER   = 'AAAAAA'

  def self.generate(fixed_asset)
    new(fixed_asset).render
  end

  def initialize(fixed_asset)
    @asset     = fixed_asset
    @novelties = fixed_asset.asset_novelties.order_by(date: :asc, created_at: :asc).to_a
  end

  def render
    pdf = Prawn::Document.new(page_size: 'A4', margin: [30, 30, 55, 30])
    pdf.font_families.update(
      'Helvetica' => {
        normal:      'Helvetica',
        bold:        'Helvetica-Bold',
        italic:      'Helvetica-Oblique',
        bold_italic: 'Helvetica-BoldOblique'
      }
    )
    pdf.font 'Helvetica'

    build_header(pdf)
    pdf.move_down 12
    build_asset_info(pdf)
    build_assignment_info(pdf) if @asset.assigned?
    pdf.move_down 14
    build_novelties(pdf)
    build_footer(pdf)

    pdf.render
  end

  private

  def build_header(pdf)
    w = pdf.bounds.width

    logo_cell = if File.exist?(LOGO_PATH)
      { image: LOGO_PATH, fit: [70, 45], position: :center,
        vposition: :center, padding: [6, 8, 6, 8] }
    else
      { content: 'MC', align: :center, font_style: :bold, valign: :center }
    end

    data = [[
      logo_cell,
      { content: "HISTORIAL DE ACTIVO FIJO\n#{@asset.name.upcase}",
        align: :center, font_style: :bold, size: 12,
        valign: :center, padding: [8, 6, 8, 6] },
      { content: "SERIAL: #{@asset.serial}\nESTADO: #{@asset.status_label.upcase}\nFECHA: #{Date.current.strftime('%d/%m/%Y')}",
        size: 9, valign: :center, padding: [6, 8, 6, 8] }
    ]]

    pdf.table(data, width: w) do |t|
      t.columns(0).width = 90
      t.columns(2).width = 140
      t.cells.border_width = 0.5
      t.cells.border_color = '000000'
      t.row(0).background_color = HEADER_BG
    end
  end

  def build_asset_info(pdf)
    w = pdf.bounds.width

    price_text = begin
      "$#{format_money(@asset.purchase_price)} COP"
    rescue
      '—'
    end

    section_title(pdf, 'INFORMACIÓN DEL ACTIVO', w)

    rows = [
      [label_cell('Nombre'),          value_cell(@asset.name.to_s)],
      [label_cell('Serial'),          value_cell(@asset.serial.to_s)],
      [label_cell('Estado'),          value_cell(@asset.status_label)],
      [label_cell('Fecha de compra'), value_cell(@asset.purchase_date&.strftime('%d/%m/%Y') || '—')],
      [label_cell('Precio de compra'), value_cell(price_text)],
      [label_cell('Responsable'),     value_cell(@asset.responsible.to_s)],
      [label_cell('Registrado el'),   value_cell(@asset.created_at.strftime('%d/%m/%Y %H:%M'))]
    ]

    pdf.table(rows, width: w) do |t|
      t.columns(0).width = 160
      t.cells.border_width = 0.5
      t.cells.border_color = BORDER
    end
  end

  def build_assignment_info(pdf)
    pdf.move_down 10
    w = pdf.bounds.width

    section_title(pdf, 'INFORMACIÓN DE ASIGNACIÓN', w)

    rows = [
      [label_cell('Asignado a'),             value_cell(@asset.assigned_to.to_s)],
      [label_cell('Fecha de asignación'),    value_cell(@asset.assigned_date&.strftime('%d/%m/%Y') || '—')],
      [label_cell('Descripción asignación'), value_cell(@asset.assigned_description.to_s)]
    ]

    pdf.table(rows, width: w) do |t|
      t.columns(0).width = 160
      t.cells.border_width = 0.5
      t.cells.border_color = BORDER
    end
  end

  def build_novelties(pdf)
    w = pdf.bounds.width

    section_title(pdf, "NOVEDADES (#{@novelties.size})", w)

    if @novelties.empty?
      pdf.move_down 4
      pdf.text 'No hay novedades registradas para este activo.', size: 9,
               style: :italic, color: '888888'
      return
    end

    @novelties.each_with_index do |nov, idx|
      pdf.start_new_page if pdf.cursor < 130

      # Encabezado de la novedad
      pdf.table([[
        { content: (idx + 1).to_s, font_style: :bold, size: 10,
          align: :center, valign: :center,
          background_color: PRIMARY, text_color: 'FFFFFF', padding: [5, 8, 5, 8] },
        { content: nov.name.upcase, font_style: :bold, size: 10,
          valign: :center, background_color: HEADER_BG, padding: [5, 8, 5, 8] },
        { content: nov.date&.strftime('%d/%m/%Y') || '—', size: 9,
          align: :right, valign: :center, background_color: HEADER_BG, padding: [5, 8, 5, 8] }
      ]], width: w) do |t|
        t.columns(0).width = 28
        t.columns(2).width = 90
        t.cells.border_width = 0.5
        t.cells.border_color = BORDER
      end

      # Detalle
      pdf.table([
        [label_cell('Responsable'), value_cell(nov.responsible.to_s)],
        [label_cell('Descripción'), value_cell(nov.description.to_s)]
      ], width: w) do |t|
        t.columns(0).width = 160
        t.cells.border_width = 0.5
        t.cells.border_color = BORDER
      end

      # Imágenes (firma y/o evidencia)
      sig_path  = novelty_file_path(nov.signature_path)
      evid_path = novelty_file_path(nov.evidence_path)

      if sig_path || evid_path
        pdf.move_down 6
        build_novelty_images(pdf, sig_path, evid_path, w)
      end

      pdf.move_down 10
    end
  end

  def build_novelty_images(pdf, sig_path, evid_path, w)
    image_cells = []
    image_cells << { label: 'FIRMA', path: sig_path }    if sig_path
    image_cells << { label: 'EVIDENCIA', path: evid_path } if evid_path

    cell_w = image_cells.size == 2 ? w / 2.0 : w * 0.45

    row_label = image_cells.map { |ic| label_cell(ic[:label]) }
    row_label.first[:colspan] = 1 if image_cells.size == 1

    # Labels row
    pdf.table([row_label], width: image_cells.size == 2 ? w : cell_w) do |t|
      t.cells.border_width = 0.5
      t.cells.border_color = BORDER
    end

    # Images row
    img_row = image_cells.map do |ic|
      begin
        { image: ic[:path], fit: [cell_w - 20, 80], position: :center,
          vposition: :center, padding: [6, 6, 6, 6] }
      rescue
        { content: '(imagen no disponible)', size: 8, color: '999999',
          align: :center, padding: [10, 6, 10, 6] }
      end
    end

    target_w = image_cells.size == 2 ? w : cell_w
    pdf.table([img_row], width: target_w) do |t|
      t.cells.border_width = 0.5
      t.cells.border_color = BORDER
    end
  end

  def build_footer(pdf)
    pdf.repeat(:all) do
      pdf.bounding_box([0, pdf.bounds.absolute_bottom + 18], width: pdf.bounds.width) do
        pdf.stroke { pdf.horizontal_rule }
        pdf.move_down 4
        pdf.text FOOTER_TEXT, size: 7, align: :center, color: '555555'
      end
    end
  end

  def section_title(pdf, text, w)
    pdf.table([[{ content: text, font_style: :bold, size: 10,
                  background_color: PRIMARY, text_color: 'FFFFFF',
                  padding: [6, 8, 6, 8] }]], width: w) do |t|
      t.cells.border_width = 0
    end
    pdf.move_down 2
  end

  def label_cell(text)
    { content: text.upcase, font_style: :bold, size: 9,
      background_color: LABEL_BG, padding: [5, 8, 5, 8] }
  end

  def value_cell(text)
    { content: text.to_s, size: 9, padding: [5, 8, 5, 8] }
  end

  def novelty_file_path(relative_path)
    return nil unless relative_path.present?
    full = Rails.root.join('public', relative_path).to_s
    File.exist?(full) ? full : nil
  end

  def format_money(money)
    return '0' if money.nil?
    cents = money.fractional.to_i
    (cents / 100).to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1.')
  rescue
    '0'
  end
end
