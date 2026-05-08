# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      # 公開 entry_schedule 読み取りの明示失敗（Presenter が I18n・HTTP へマッピング）
      EntryScheduleFailureDto = Struct.new(:kind, :detail_message, keyword_init: true) do
        def self.record_not_found(message)
          new(kind: :record_not_found, detail_message: message)
        end

        def self.weather_location_required
          new(kind: :weather_location_required, detail_message: nil)
        end

        def self.prediction_payload_missing
          new(kind: :prediction_payload_missing, detail_message: nil)
        end

        def self.weather_prediction_failed(message)
          new(kind: :weather_prediction_failed, detail_message: message)
        end

        def self.internal_error(message)
          new(kind: :internal_error, detail_message: message)
        end
      end
    end
  end
end
