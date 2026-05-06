# frozen_string_literal: true

module Domain
  module ApiWeather
    module Dtos
      # HTTP 用の失敗理由（Presenter が I18n / ステータスに写す）
      class ApiWeatherFailureDto
        KIND_LOCATION_REQUIRED = :location_required
        KIND_DAEMON_UNAVAILABLE = :daemon_unavailable
        KIND_COMMAND_FAILED = :command_failed
        KIND_INVALID_JSON = :invalid_json

        attr_reader :kind, :message

        def initialize(kind, message = nil)
          @kind = kind
          @message = message
        end
      end
    end
  end
end
