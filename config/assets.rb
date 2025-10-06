# frozen_string_literal: true

# Propshaft configuration for Rails 8
Rails.application.configure do
  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "https://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  # config.log_level = :debug

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "agrr_production"

  # config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  # config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  # config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  # config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  # if ENV["RAILS_LOG_TO_STDOUT"].present?
  #   logger           = ActiveSupport::Logger.new(STDOUT)
  #   logger.formatter = config.log_formatter
  #   config.logger    = ActiveSupport::TaggedLogging.new(logger)
  # end

  # Do not dump schema after migrations.
  # config.active_record.dump_schema_after_migration = false

  # Inserts middleware to perform automatic connection switching.
  # The `database_selector` hash is used to pass any options that you would use
  # to `DatabaseSelector#call` (e.g. `shard`, `database_selector: { writing: :primary }`).
  # By default Rails will store a last write timestamp in the session. The
  # `DatabaseSelector` middleware uses this timestamp to determine how long to wait
  # before reading from the replica.
  #
  # By default Rails will store a last write timestamp in the session. The
  # `DatabaseSelector` middleware uses this timestamp to determine how long to wait
  # before reading from the replica.
  #
  # These settings can be overridden in specific environments using the files
  # in config/environments, which are processed later.
  #
  # config.active_record.database_selector = { delay: 2.seconds }
  # config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  # config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
end
