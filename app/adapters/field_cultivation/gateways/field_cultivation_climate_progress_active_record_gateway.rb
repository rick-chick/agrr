# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateProgressGateway
        include ::Adapters::FieldCultivation::MockProgressRecords

        def initialize(current_user:, logger:, progress_gateway_factory:)
          @current_user = current_user
          @logger = logger
          @progress_gateway_factory = progress_gateway_factory
        end

        def calculate_progress(context:, weather_payload:, use_mock:)
          return mock_progress_result(context) if use_mock

          crop = fetch_crop(context)
          raise Domain::Shared::Exceptions::RecordNotFound, "crop not found" unless crop

          progress_gateway = @progress_gateway_factory.call
          progress_gateway.calculate_progress(
            crop: crop,
            start_date: context.start_date,
            weather_data: weather_payload
          )
        end

        private

        def fetch_crop(context)
          field_cultivation = ::FieldCultivation.find(context.field_cultivation_id)
          plan_crop = field_cultivation.cultivation_plan_crop
          if context.plan_type_public
            ::Crop.find_by(id: plan_crop.crop_id)
          else
            return nil unless @current_user

            ::Crop.where(user_id: @current_user.id, is_reference: false).find_by(id: plan_crop.crop_id)
          end
        end

        def mock_progress_result(context)
          @logger.info "🧪 [FieldCultivationClimateProgressActiveRecordGateway] Using mock progress for field_cultivation_id=#{context.field_cultivation_id}"
          {
            "progress_records" => generate_mock_progress_records(
              context.start_date,
              context.completion_date,
              logger: @logger
            ),
            "total_gdd" => 875.0
          }
        end
      end
    end
  end
end
