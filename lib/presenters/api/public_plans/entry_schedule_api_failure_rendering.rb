# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      # entry_schedule 系 API Presenter 共通: 失敗 DTO を契約どおりの JSON に載せる
      module EntryScheduleApiFailureRendering
        private

        def render_entry_schedule_failure(dto)
          @view.render json: {
            error: entry_schedule_failure_message(dto),
            error_key: entry_schedule_failure_key(dto)
          }, status: entry_schedule_failure_status(dto)
        end

        def entry_schedule_failure_message(dto)
          case dto.kind
          when :record_not_found
            dto.detail_message.to_s
          when :weather_location_required
            I18n.t("api.entry_schedule.errors.weather_location_required")
          when :prediction_payload_missing
            I18n.t("api.errors.common.no_weather_data")
          when :weather_prediction_failed
            dto.detail_message.to_s
          when :internal_error
            dto.detail_message.to_s
          else
            dto.detail_message.to_s
          end
        end

        def entry_schedule_failure_key(dto)
          case dto.kind
          when :record_not_found
            "api.errors.common.farm_not_found"
          when :weather_location_required
            "api.entry_schedule.errors.weather_location_required"
          when :prediction_payload_missing
            "api.errors.common.no_weather_data"
          when :weather_prediction_failed
            "api.entry_schedule.errors.prediction_failed"
          else
            "api.errors.common.farm_not_found"
          end
        end

        def entry_schedule_failure_status(dto)
          case dto.kind
          when :record_not_found
            :not_found
          when :weather_location_required, :prediction_payload_missing
            :unprocessable_entity
          when :weather_prediction_failed
            :service_unavailable
          when :internal_error
            :internal_server_error
          else
            :internal_server_error
          end
        end
      end
    end
  end
end
