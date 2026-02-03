# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractor < Domain::FieldCultivation::Ports::FieldCultivationClimateDataInputPort
        def initialize(output_port:, gateway:, logger: Rails.logger)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
        end

        def call(input_dto)
          climate_data = @gateway.fetch_field_cultivation_climate_data(
            field_cultivation_id: input_dto.field_cultivation_id
          )

          if climate_data.nil?
            @logger.warn(
              "[FieldCultivationClimateDataInteractor] Missing climate data "\
              "for field_cultivation_id=#{input_dto.field_cultivation_id}"
            )
            @output_port.on_error(
              Domain::Shared::Dtos::ErrorDto.new('Field cultivation climate data not found')
            )
            return
          end

          @output_port.present(climate_data)
        rescue ActiveRecord::RecordNotFound => e
          @logger.warn(
            "[FieldCultivationClimateDataInteractor] Field cultivation not found: #{e.message}"
          )
          @output_port.on_error(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @logger.error(
            "[FieldCultivationClimateDataInteractor] Unexpected error: #{e.class}: #{e.message}"
          )
          @logger.error(e.backtrace.join("\n")) if e.backtrace
          @output_port.on_error(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
