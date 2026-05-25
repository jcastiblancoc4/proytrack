class AssetAttachmentUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_allowlist
    %w[jpg jpeg png gif webp pdf]
  end

  def content_type_allowlist
    [/image\//, 'application/pdf']
  end
end
