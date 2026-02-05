require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  
  # Set cache headers for static assets (1 year cache for assets with hash in filename)
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.year.to_i}"
  }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on local disk for App Runner deployment
  # Use S3 only when AWS_S3_BUCKET is explicitly set
  config.active_storage.service = ENV["AWS_S3_BUCKET"].present? ? :amazon_env : :local

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl to ensure the SSL redirect happens.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Info include generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use Solid Cache for production caching (SQLite-based)
  config.cache_store = :solid_cache_store

  # Use async adapter for background jobs in single-instance production
  config.active_job.queue_adapter = :async
  config.active_job.queue_name_prefix = "agrr_production"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection and other features
  # Allow localhost and App Runner internal IPs for health checks
  config.hosts << "localhost"
  config.hosts << ".awsapprunner.com"
  config.hosts << /.*\.run\.app$/  # Google Cloud Run (format: service-hash-region.a.run.app)
  config.hosts << "agrr.net"
  config.hosts << "www.agrr.net"
  config.hosts << /169\.254\.\d+\.\d+/  # App Runner internal health check IPs
  allowed_hosts = ENV.fetch("ALLOWED_HOSTS", "").split(",").reject(&:empty?)
  config.hosts.concat(allowed_hosts) unless allowed_hosts.empty?

  # Use Solid Cable for Action Cable (SQLite-based)
  # Note: Action Cable adapter should be configured in config/cable.yml instead
  # config.action_cable.adapter = :solid_cable
  
  # Google OAuth production configuration
  config.after_initialize do
    # Production OAuth credentials should be set via environment variables
    # GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be configured
    unless ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
      Rails.logger.error "🚨 CRITICAL: Google OAuth credentials not configured for production!"
      Rails.logger.error "   Please set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET environment variables"
      Rails.logger.error "   Google OAuth authentication will not work without these credentials"
    else
      Rails.logger.info "✅ Google OAuth credentials configured for production"
    end
  end
end
