# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateCreateInteractor
        def initialize(output_port:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call(input_dto)
          unless Domain::Shared::ValidationHelpers.present?(input_dto.agricultural_task_id)
            return @output_port.on_failure(
              Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailureDto.new(
                reason: :missing_agricultural_task_id
              )
            )
          end

          user = @user_lookup.find(input_dto.user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          result = @gateway.create_masters_crop_task_template_association(user, input_dto, access_filter: access_filter)

          if result.failure?
            @output_port.on_failure(result.failure)
          else
            @output_port.on_success(result.template)
          end
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(
            Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailureDto.new(
              reason: :validation_failed,
              errors: e.flatten_error_messages
            )
          )
        end
      end
    end
  end
end
