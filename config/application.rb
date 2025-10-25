# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Agrr
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Add lib directory to autoload paths for Clean Architecture
    config.autoload_paths += %W(#{config.root}/lib)
    config.eager_load_paths += %W(#{config.root}/lib)

    # Use SQLite for caching
    config.cache_store = :solid_cache_store

    # Use SQLite for background jobs
    config.active_job.queue_adapter = :solid_queue

    # Action Cable configuration is now in config/cable.yml

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Configure CORS
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end

    # Propshaft configuration (Rails 8 default asset pipeline)
    config.assets.enabled = true
    config.assets.version = '1.0'
    config.assets.paths << Rails.root.join('vendor/assets/stylesheets')
    
    # Add builds directory to Propshaft load paths (for esbuild output)
    config.assets.paths << Rails.root.join('app/assets/builds')
    
    # Propshaft specific configuration
    config.assets.configure do |env|
      env.logger = Rails.logger
    end

    # I18n configuration
    config.i18n.default_locale = :ja
    config.i18n.available_locales = [:ja, :us, :in]
    config.i18n.fallbacks = [:us]
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
  end
end