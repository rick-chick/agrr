require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing (Rails 6.1 doesn't have this)
  # config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.variant_processor = :mini_magick

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true
  
  # Propshaft configuration for development
  # Propshaft handles assets automatically in development, no compilation needed
  # config.assets.prefix = '/assets'
  # config.assets.compile = true  # Not needed for Propshaft
  # config.assets.digest = false  # Propshaft handles this automatically
  # config.assets.debug = true
  
  # Enable static file serving in development
  config.public_file_server.enabled = true
  
  # Propshaft specific configuration
  config.assets.configure do |env|
    env.logger = Rails.logger
  end

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # ActionCable configuration for WebSocket
  config.action_cable.url = "ws://localhost:3000/cable"
  config.action_cable.mount_path = "/cable"
  config.action_cable.allowed_request_origins = [
    /http:\/\/localhost:\d+/,
    /http:\/\/127\.0\.0\.1:\d+/
  ]
  config.action_cable.disable_request_forgery_protection = false

  # Raise error when a before_action's only/except options reference missing actions (Rails 6.1 doesn't have this)
  # config.action_controller.raise_on_missing_callback_actions = true

  # Use local file storage for development
  # config.active_storage.service = :local

  # Use async adapter for background jobs in development (simpler than Solid Queue)
  # APの軽量化優先：最小限のスレッド数でAPへの影響を最小化
  config.active_job.queue_adapter = :async
  config.active_job.async_queue_size = 1
  
  # 特定のキューに対してスレッド数を制限
  config.after_initialize do
    if Rails.env.development?
      # 天気データ取得ジョブを順次実行
      Rails.application.config.active_job.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new(
        min_threads: 1,
        max_threads: 1,
        queues: {
          'weather_data_sequential' => 1,
          'default' => 1
        }
      )
    end
  end

  # Set log level to info to see background job logs
  config.log_level = :debug # デバッグログを有効化（問題の切り分け用）

  # Allow local hosts during development
  config.hosts << "localhost"
  config.hosts << "127.0.0.1"

  # Content Security Policy for development
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval
    policy.style_src   :self, :https, :unsafe_inline
  end

  # Google OAuth development configuration
  config.after_initialize do
    # Set development OAuth credentials (replace with your actual credentials)
    ENV['GOOGLE_CLIENT_ID'] ||= 'your_google_client_id_here'
    ENV['GOOGLE_CLIENT_SECRET'] ||= 'your_google_client_secret_here'
  end
end
