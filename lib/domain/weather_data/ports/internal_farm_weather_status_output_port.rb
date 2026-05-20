# frozen_string_literal: true

module Domain
  module WeatherData
    module Ports
      # 内部 API 用・農場天気ステータス取得インターラクタの出力ポート。
      class InternalFarmWeatherStatusOutputPort
        # @param dto [Domain::WeatherData::Dtos::InternalFarmWeatherStatusOutput]
        def on_success(dto)
          raise NotImplementedError
        end

        # @param failure_dto [Domain::WeatherData::Dtos::InternalWeatherFetchFailure]
        def on_failure(failure_dto)
          raise NotImplementedError
        end
      end
    end
  end
end
