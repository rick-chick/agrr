# frozen_string_literal: true

module Api
  module FieldCultivationClimate
    class FieldCultivationClimateDataPresenter < Domain::FieldCultivation::Ports::FieldCultivationClimateDataOutputPort
      NOT_FOUND_PATTERNS = [
        /not\s+found/i,
        /missing/i,
        /見つかりません/,
        /weather data/i,
        /気象データがありません/,
        /crop information/i,
        /field cultivation/i
      ].freeze
      BAD_REQUEST_PATTERNS = [
        /栽培期間/,
        /cultivation period/i,
        /start_date/i,
        /completion_date/i
      ].freeze

      def initialize(view:)
        @view = view
      end

      def present(success_dto)
        on_success(success_dto)
      end

      def on_success(success_dto)
        view.render_response(
          json: success_payload(success_dto),
          status: :ok
        )
      end

      def on_error(error_dto)
        on_failure(error_dto)
      end

      def on_failure(error_dto)
        message = error_message(error_dto)

        view.render_response(
          json: failure_payload(message),
          status: status_for(message)
        )
      end

      private

      attr_reader :view

      def success_payload(dto)
        {
          success: true,
          field_cultivation: dto.field_cultivation,
          farm: dto.farm,
          crop_requirements: dto.crop_requirements,
          weather_data: dto.weather_data,
          gdd_data: dto.gdd_data,
          stages: dto.stages,
          progress_result: dto.progress_result,
          debug_info: dto.debug_info
        }
      end

      def failure_payload(message)
        {
          success: false,
          message: message
        }
      end

      def error_message(dto)
        return dto.message if dto.respond_to?(:message)

        dto.to_s
      end

      def status_for(message)
        return :internal_server_error if message.nil?

        normalized = message.to_s

        return :bad_request if BAD_REQUEST_PATTERNS.any? { |pattern| normalized.match?(pattern) }
        return :not_found if NOT_FOUND_PATTERNS.any? { |pattern| normalized.match?(pattern) }

        :internal_server_error
      end
    end
  end
end
