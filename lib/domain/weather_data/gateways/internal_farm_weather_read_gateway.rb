# frozen_string_literal: true

module Domain
  module WeatherData
    module Gateways
      # 内部 API 用の農場天気スナップショット（実装はアダプタ）。
      module InternalFarmWeatherReadGateway
        # @return [Domain::WeatherData::Dtos::InternalFarmWeatherStatusResult]
        def weather_status_snapshot(farm_id:)
          raise NotImplementedError
        end

        # @return [Domain::WeatherData::Dtos::InternalFarmWeatherDataListResult]
        def weather_data_list_snapshot(farm_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
