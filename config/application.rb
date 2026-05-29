# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Adapters 名前空間（gateway 実装・presenter）は app/adapters/ に置く。
# app/* は本来 namespace 無し root になるため、namespace を明示する push_dir
# （下記）に渡せるよう、ここで先行定義しておく。
module Adapters; end

module Agrr
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # User uploads are not used; keep Active Storage engine defaults without /rails/active_storage routes.
    config.active_storage.draw_routes = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Add lib directory to autoload paths for Clean Architecture
    config.autoload_paths += %W[#{config.root}/lib]
    config.eager_load_paths += %W[#{config.root}/lib]

    # Gateway 実装・presenter は app/adapters/<context>/ 配下に置き、namespace は
    # Adapters:: を維持する。app/* ディレクトリは通常 namespace 無しの autoload root に
    # なるため、Adapters namespace を明示して push_dir する（Rails の set_autoload_paths /
    # setup_once_autoloader は既に push 済みの dir を再登録しないため衝突しない）。
    Rails.autoloaders.main.push_dir("#{config.root}/app/adapters", namespace: Adapters)

    # Use SQLite for caching
    config.cache_store = :solid_cache_store

    # Use SQLite for background jobs (async adapter; Solid Queue 廃止)
    config.active_job.queue_adapter = :async

    # Action Cable configuration is now in config/cable.yml

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Configure CORS
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        frontend_origins = ENV.fetch("FRONTEND_URL", "http://localhost:4200")
                              .split(",")
                              .map(&:strip)
                              .reject(&:empty?)
        origins(*frontend_origins)
        resource "/api/*",
                 headers: :any,
                 methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
                 credentials: true
        # undo_deletion: /undo_deletion または /:locale/undo_deletion（Angular からの復元用）
        resource %r{^(/(ja|us|in))?/undo_deletion$},
                 headers: :any,
                 methods: [ :post, :options ],
                 credentials: true
        resource "/cable",
                 headers: :any,
                 methods: [ :get, :post, :options ],
                 credentials: true
      end
    end


    # Propshaft configuration (Rails 8 default asset pipeline)
    config.assets.enabled = true
    config.assets.version = "1.0"
    config.assets.paths << Rails.root.join("vendor/assets/stylesheets")

    # Add builds directory to Propshaft load paths (for esbuild output)
    config.assets.paths << Rails.root.join("app/assets/builds")

    # Propshaft specific configuration
    config.assets.configure do |env|
      env.logger = Rails.logger
    end

    # I18n configuration
    config.i18n.default_locale = :ja
    config.i18n.available_locales = [ :ja, :us, :in ]
    config.i18n.fallbacks = { in: :ja, us: :en, en: :us }
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
  end
end
