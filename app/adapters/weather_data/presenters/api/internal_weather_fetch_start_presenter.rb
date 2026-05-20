# frozen_string_literal: true

module Adapters
  module WeatherData
    module Presenters
      module Api
        class InternalWeatherFetchStartPresenter < Domain::WeatherData::Ports::InternalWeatherFetchStartOutputPort
          def initialize(view:, translator:)
            @view = view
            @translator = translator
          end

          def on_success(success_dto)
            base = {
              success: true,
              farm_id: success_dto.farm_id,
              status: success_dto.weather_data_status
            }
            json =
              case success_dto.variant
              when Domain::WeatherData::Dtos::InternalWeatherFetchStartOutput::VARIANT_ALREADY_COMPLETED
                base.merge(
                  message: @translator.t("api.messages.common.weather_data_already_exists"),
                  weather_data_count: success_dto.weather_data_count
                )
              when Domain::WeatherData::Dtos::InternalWeatherFetchStartOutput::VARIANT_FETCH_STARTED
                base.merge(
                  message: @translator.t("api.messages.common.weather_data_fetch_started"),
                  total_blocks: success_dto.total_blocks
                )
              else
                raise ArgumentError, "unexpected success variant: #{success_dto.variant.inspect}"
              end
            @view.render_response(json: json, status: :ok)
          end

          def on_failure(failure_dto)
            @view.render_response(json: { error: failure_dto.message }, status: failure_dto.http_status)
          end
        end
      end
    end
  end
end
