# config/puma.rb

threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV") { "development" }

if ENV.fetch("RAILS_ENV") == "production"
  workers ENV.fetch("WEB_CONCURRENCY") { 2 }
  preload_app!

  # Socket UNIX para producción
  bind "unix:///home/deploy/proytrack/tmp/sockets/puma.sock"

  pidfile "tmp/pids/puma.pid"
  state_path "tmp/pids/puma.state"
  stdout_redirect "log/puma.stdout.log", "log/puma.stderr.log", true

  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
    Mongoid::Clients.default unless defined?(Mongoid)
  end
else
  # Para desarrollo local con rails s
  port ENV.fetch("PORT") { 3000 }
end
