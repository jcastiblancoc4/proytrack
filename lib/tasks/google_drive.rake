namespace :google_drive do
  desc 'Autoriza la cuenta de Google y muestra el refresh token y el ID de la carpeta de soportes'
  task authorize: :environment do
    require 'signet/oauth_2/client'
    require 'socket'

    client_id     = ENV['GOOGLE_DRIVE_CLIENT_ID']
    client_secret = ENV['GOOGLE_DRIVE_CLIENT_SECRET']
    abort 'Define GOOGLE_DRIVE_CLIENT_ID y GOOGLE_DRIVE_CLIENT_SECRET en el .env antes de continuar.' if client_id.blank? || client_secret.blank?

    port = 8085
    client = Signet::OAuth2::Client.new(
      authorization_uri:     'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri:  'https://oauth2.googleapis.com/token',
      client_id:             client_id,
      client_secret:         client_secret,
      scope:                 GoogleDriveService::SCOPE,
      redirect_uri:          "http://127.0.0.1:#{port}",
      additional_parameters: { access_type: 'offline', prompt: 'consent' }
    )

    # Servidor local que recibe la redirección de Google con el código de autorización
    server = TCPServer.new('127.0.0.1', port)

    puts "\nAbre esta URL en el navegador, inicia sesión con la cuenta de Google y acepta:\n\n"
    puts client.authorization_uri.to_s
    puts "\nEsperando la autorización en http://127.0.0.1:#{port} ..."
    $stdout.flush

    code = nil
    until code
      socket = server.accept
      request_line = socket.gets.to_s
      query = URI(request_line.split(' ')[1].to_s).query.to_s rescue ''
      params = URI.decode_www_form(query).to_h
      code = params['code']

      message = if code
                  'Autorización completada. Ya puedes cerrar esta pestaña y volver a la terminal.'
                elsif params['error']
                  "Autorización rechazada: #{params['error']}"
                else
                  'Esperando autorización...'
                end
      body = "<html><head><meta charset='utf-8'></head><body style='font-family:sans-serif;padding:2rem'><h2>Proytrack</h2><p>#{ERB::Util.html_escape(message)}</p></body></html>"
      socket.print "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
      socket.close

      abort "Autorización rechazada: #{params['error']}" if params['error']
    end
    server.close

    client.code = code
    client.fetch_access_token!

    ENV['GOOGLE_DRIVE_REFRESH_TOKEN'] = client.refresh_token
    folder_id = ENV['GOOGLE_DRIVE_FOLDER_ID'].presence || GoogleDriveService.create_folder('Proytrack - Soportes de gastos')

    puts "\nListo. Agrega estas líneas al .env:\n\n"
    puts "GOOGLE_DRIVE_REFRESH_TOKEN=#{client.refresh_token}"
    puts "GOOGLE_DRIVE_FOLDER_ID=#{folder_id}"
  end
end
