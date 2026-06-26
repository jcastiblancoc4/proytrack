class FixedAssetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_fixed_asset, only: [:show, :edit, :update, :destroy, :download_pdf]

  def index
    @query = params[:q].to_s.strip
    @fixed_assets = if @query.present?
      FixedAsset.where(
        user_id: current_user.id,
        '$or' => [
          { name:   { '$regex' => @query, '$options' => 'i' } },
          { serial: { '$regex' => @query, '$options' => 'i' } }
        ]
      )
    else
      current_user.fixed_assets
    end
    @fixed_assets = @fixed_assets.order_by(created_at: :desc)
  end

  def show
  end

  def download_pdf
    pdf_data = FixedAssetPdf.generate(@fixed_asset)
    filename  = "activo_#{@fixed_asset.serial.gsub(/[^a-zA-Z0-9_-]/, '_')}_#{Date.current.strftime('%Y%m%d')}.pdf"
    send_data pdf_data, filename: filename, type: 'application/pdf', disposition: 'attachment'
  end

  def new
    @fixed_asset = current_user.fixed_assets.build
  end

  def create
    @fixed_asset = current_user.fixed_assets.build(fixed_asset_params)

    attachment_file = params.dig(:fixed_asset, :attachment_file)
    if attachment_file.present? && !valid_attachment?(attachment_file)
      @fixed_asset.errors.add(:attachment_file, 'debe ser una imagen (JPG, PNG, GIF, WebP) o un PDF')
      render :new, status: :unprocessable_entity and return
    end

    if @fixed_asset.save
      store_attachment(@fixed_asset, attachment_file) if attachment_file.present?
      redirect_to fixed_assets_path, notice: 'Activo fijo registrado correctamente.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attachment_file = params.dig(:fixed_asset, :attachment_file)
    remove = params.dig(:fixed_asset, :remove_attachment) == '1'

    if attachment_file.present? && !valid_attachment?(attachment_file)
      @fixed_asset.errors.add(:attachment_file, 'debe ser una imagen (JPG, PNG, GIF, WebP) o un PDF')
      render :edit, status: :unprocessable_entity and return
    end

    if @fixed_asset.update(fixed_asset_params)
      if remove
        delete_attachment_file(@fixed_asset)
        @fixed_asset.set(attachment_path: nil, attachment_content_type: nil)
      elsif attachment_file.present?
        delete_attachment_file(@fixed_asset)
        store_attachment(@fixed_asset, attachment_file)
      end
      redirect_to fixed_asset_path(@fixed_asset), notice: 'Activo fijo actualizado correctamente.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    delete_attachment_file(@fixed_asset)
    @fixed_asset.destroy
    redirect_to fixed_assets_path, notice: 'Activo fijo eliminado correctamente.'
  end

  private

  def set_fixed_asset
    @fixed_asset = current_user.fixed_assets.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to fixed_assets_path, alert: 'Activo no encontrado.'
  end

  def fixed_asset_params
    params.require(:fixed_asset).permit(
      :name, :serial, :purchase_date, :purchase_price, :responsible, :status_cd,
      :assigned_to, :assigned_date, :assigned_description
    )
  end

  def valid_attachment?(file)
    return false unless file.respond_to?(:content_type)
    FixedAsset::ALLOWED_CONTENT_TYPES.include?(file.content_type)
  end

  def store_attachment(asset, file)
    dir = Rails.root.join('public', 'uploads', 'fixed_assets', asset.id.to_s)
    FileUtils.mkdir_p(dir)
    safe_name = file.original_filename.gsub(/[^a-zA-Z0-9._-]/, '_')
    filename  = "#{SecureRandom.hex(8)}_#{safe_name}"
    File.open(dir.join(filename), 'wb') { |f| f.write(file.read) }
    relative  = "uploads/fixed_assets/#{asset.id}/#{filename}"
    asset.set(attachment_path: relative, attachment_content_type: file.content_type)
  end

  def delete_attachment_file(asset)
    return unless asset.attachment_path.present?
    full_path = Rails.root.join('public', asset.attachment_path)
    File.delete(full_path) if File.exist?(full_path)
  rescue StandardError
    # Ignore file deletion errors
  end
end
