# frozen_string_literal: true

module Domain
  module WeatherData
    module Gateways
      # 内部 API 用: 農場の天気データ取得ジョブ投入（永続化境界は Adapter）。
      module InternalWeatherFetchStartGateway
        WeatherFetchFarmSnapshot = Struct.new(:farm_id, :weather_data_status, :weather_data_count, :total_blocks, keyword_init: true)

        StartInternalWeatherFetchResult = Struct.new(:kind, :snapshot, :error_message, keyword_init: true) do
          def self.farm_not_found
            new(kind: :farm_not_found)
          end

          def self.completed(snapshot)
            new(kind: :completed, snapshot: snapshot)
          end

          def self.started(snapshot)
            new(kind: :started, snapshot: snapshot)
          end

          def self.failed(message)
            new(kind: :failed, error_message: message)
          end
        end

        def start_internal_weather_data_fetch(farm_id:)
          raise NotImplementedError, "#{self.class} must implement start_internal_weather_data_fetch"
        end
      end
    end
  end
end
