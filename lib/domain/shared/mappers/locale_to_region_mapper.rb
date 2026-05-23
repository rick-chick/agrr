# frozen_string_literal: true

module Domain
  module Shared
    module Mappers
      # アプリ locale（:ja 等）を参照農場の region コードへ写す。
      class LocaleToRegionMapper
        def self.call(locale)
          case locale.to_s
          when "ja"
            "jp"
          when "us"
            "us"
          when "in"
            "in"
          else
            "jp"
          end
        end
      end
    end
  end
end
