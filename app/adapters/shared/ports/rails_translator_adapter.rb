# frozen_string_literal: true

require "i18n"

module Adapters
  module Shared
    module Ports
      # Rails I18n を用いた翻訳アダプタ（Infrastructure Port 実装）。
      # interface: Domain::Shared::Ports::TranslatorPort
      class RailsTranslatorAdapter
        include Domain::Shared::Ports::TranslatorPort

        def translate(key, **options)
          I18n.t(key, **options)
        end

        def localize(date, format: nil, **options)
          I18n.l(date, format: format, **options)
        end
      end
    end
  end
end
