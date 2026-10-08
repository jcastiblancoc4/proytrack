require 'google/apis/drive_v3'
require 'googleauth'

# Sube, descarga y elimina archivos en Google Drive usando la cuenta personal
# configurada vía OAuth (refresh token). Ver lib/tasks/google_drive.rake para
# obtener las credenciales.
class GoogleDriveService
  class Error < StandardError; end

  SCOPE = 'https://www.googleapis.com/auth/drive.file'.freeze
  MUTEX = Mutex.new

  class << self
    # Sube el archivo a la carpeta configurada y devuelve el ID del archivo en Drive.
    def upload(io, filename:, content_type:)
      metadata = { name: filename }
      metadata[:parents] = [folder_id] if folder_id.present?

      file = drive.create_file(metadata, upload_source: io, content_type: content_type, fields: 'id')
      file.id
    rescue Google::Apis::Error, Signet::AuthorizationError => e
      raise Error, e.message
    end

    # Devuelve el contenido binario del archivo.
    def download(file_id)
      io = StringIO.new
      io.set_encoding(Encoding::BINARY)
      drive.get_file(file_id, download_dest: io)
      io.string
    rescue Google::Apis::Error, Signet::AuthorizationError => e
      raise Error, e.message
    end

    def delete(file_id)
      return if file_id.blank?

      drive.delete_file(file_id)
    rescue Google::Apis::ClientError => e
      # El archivo ya no existe en Drive: no hay nada que borrar
      raise Error, e.message unless e.status_code == 404
    rescue Google::Apis::Error, Signet::AuthorizationError => e
      raise Error, e.message
    end

    def create_folder(name)
      folder = drive.create_file({ name: name, mime_type: 'application/vnd.google-apps.folder' }, fields: 'id')
      folder.id
    end

    def configured?
      ENV['GOOGLE_DRIVE_CLIENT_ID'].present? &&
        ENV['GOOGLE_DRIVE_CLIENT_SECRET'].present? &&
        ENV['GOOGLE_DRIVE_REFRESH_TOKEN'].present?
    end

    private

    def folder_id
      ENV['GOOGLE_DRIVE_FOLDER_ID']
    end

    # Se reutiliza entre peticiones: las credenciales guardan el access token (válido ~1 hora)
    # y lo renuevan solas al vencer, en vez de pedir uno nuevo a Google en cada llamada.
    def drive
      raise Error, 'Google Drive no está configurado' unless configured?

      MUTEX.synchronize do
        @drive ||= Google::Apis::DriveV3::DriveService.new.tap do |service|
          service.authorization = Google::Auth::UserRefreshCredentials.new(
            client_id:     ENV['GOOGLE_DRIVE_CLIENT_ID'],
            client_secret: ENV['GOOGLE_DRIVE_CLIENT_SECRET'],
            refresh_token: ENV['GOOGLE_DRIVE_REFRESH_TOKEN'],
            scope:         SCOPE
          )
        end
      end
    end
  end
end
