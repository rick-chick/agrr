# frozen_string_literal: true

module Domain
  module WeatherData
    module Ports
      class FarmWeatherDataAccessOutputPort
        def on_index_success(farm:, period:, data:)
          raise NotImplementedError, "#{self.class} must implement on_index_success"
        end

        def on_prediction_cached_success(farm:, period:, is_prediction:, predicted_at:, model:, data:)
          raise NotImplementedError, "#{self.class} must implement on_prediction_cached_success"
        end

        def on_prediction_queued(farm_id:, farm_name:)
          raise NotImplementedError, "#{self.class} must implement on_prediction_queued"
        end

        def on_farm_not_found
          raise NotImplementedError, "#{self.class} must implement on_farm_not_found"
        end

        def on_no_weather_location
          raise NotImplementedError, "#{self.class} must implement on_no_weather_location"
        end

        def on_insufficient_historical_data
          raise NotImplementedError, "#{self.class} must implement on_insufficient_historical_data"
        end

        def on_enqueue_failed(error_message:)
          raise NotImplementedError, "#{self.class} must implement on_enqueue_failed"
        end
      end
    end
  end
end
