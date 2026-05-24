# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateWeatherGateway
        # @param context [Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot]
        # @return [Hash] AGRR 形式の気象ペイロード
        # @raise [Domain::FieldCultivation::Errors::WeatherPayloadInvalidError]
        def fetch_primary_weather_payload(context:, display_start_date: nil, display_end_date: nil)
          raise NotImplementedError
        end

        # @param context [Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot]
        # @return [Hash] AGRR 形式の気象ペイロード
        def fetch_fallback_weather_payload(context:, display_start_date: nil, display_end_date: nil)
          raise NotImplementedError
        end

        def persist_predicted_weather_if_absent(plan_id:, weather_payload:)
          raise NotImplementedError
        end
      end
    end
  end
end
