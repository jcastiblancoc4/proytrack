class AssetNoveltiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_fixed_asset
  before_action :set_novelty, only: [:show, :destroy]

  def new
    @novelty = @fixed_asset.asset_novelties.build
  end

  def create
    @novelty = @fixed_asset.asset_novelties.build(novelty_params)

    evidence_file = params.dig(:asset_novelty, :evidence_file)
    if evidence_file.present? && !valid_evidence?(evidence_file)
      @novelty.errors.add(:evidence_file, 'debe ser una imagen (JPG, PNG, GIF o WebP)')
      render :new, status: :unprocessable_entity and return
    end

    if @novelty.save
      save_signature(@novelty, params[:signature_data])
      store_evidence(@novelty, evidence_file) if evidence_file.present?
      redirect_to fixed_asset_path(@fixed_asset), notice: 'Novedad registrada correctamente.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def destroy
    delete_novelty_files(@novelty)
    @novelty.destroy
    redirect_to fixed_asset_path(@fixed_asset), notice: 'Novedad eliminada correctamente.'
  end

  private

  def set_fixed_asset
    @fixed_asset = current_user.fixed_assets.find(params[:fixed_asset_id])
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to fixed_assets_path, alert: 'Activo no encontrado.'
  end

  def set_novelty
    @novelty = @fixed_asset.asset_novelties.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to fixed_asset_path(@fixed_asset), alert: 'Novedad no encontrada.'
  end

  def novelty_params
    params.require(:asset_novelty).permit(:name, :date, :description, :responsible)
  end

  def valid_evidence?(file)
    return false unless file.respond_to?(:content_type)
    AssetNovelty::ALLOWED_EVIDENCE_TYPES.include?(file.content_type)
  end

  def save_signature(novelty, signature_data)
    return unless signature_data.present?
    base64   = signature_data.sub(/\Adata:image\/\w+;base64,/, '')
    binary   = Base64.decode64(base64)
    relative = "uploads/asset_novelties/#{novelty.id}/signature_#{novelty.id}.png"
    dest     = Rails.root.join('public', relative)
    FileUtils.mkdir_p(dest.dirname)
    File.binwrite(dest.to_s, binary)
    novelty.set(signature_path: relative)
  rescue => e
    Rails.logger.error "Signature save failed for AssetNovelty #{novelty.id}: #{e.message}"
  end

  def store_evidence(novelty, file)
    dir      = Rails.root.join('public', 'uploads', 'asset_novelties', novelty.id.to_s)
    FileUtils.mkdir_p(dir)
    safe     = file.original_filename.gsub(/[^a-zA-Z0-9._-]/, '_')
    filename = "#{SecureRandom.hex(8)}_#{safe}"
    File.open(dir.join(filename), 'wb') { |f| f.write(file.read) }
    relative = "uploads/asset_novelties/#{novelty.id}/#{filename}"
    novelty.set(evidence_path: relative, evidence_content_type: file.content_type)
  end

  def delete_novelty_files(novelty)
    [novelty.signature_path, novelty.evidence_path].compact.each do |path|
      full = Rails.root.join('public', path)
      File.delete(full) if File.exist?(full)
    end
  rescue StandardError
  end
end
