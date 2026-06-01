# frozen_string_literal: true

require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Agrr
  class Application < Rails::Application
    config.load_defaults 8.0

    config.active_storage.draw_routes = false
    config.active_job.queue_adapter = :test
    config.cache_store = :memory_store
    config.generators.system_tests = nil

    config.autoload_paths += %W[#{config.root}/lib]
    config.eager_load_paths += %W[#{config.root}/lib]

    config.i18n.default_locale = :ja
    config.i18n.available_locales = %i[ja us in]
    config.i18n.fallbacks = { in: :ja, us: :en, en: :us }
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
  end
end
