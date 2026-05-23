# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateCreateInteractor
        def initialize(output_port:, gateway:, user_lookup:, agricultural_task_gateway:)
          @output_port = output_port
          @gateway = gateway
          @user_lookup = user_lookup
          @agricultural_task_gateway = agricultural_task_gateway
        end

        def call(input_dto)
          unless Domain::Shared.present?(input_dto.agricultural_task_id)
            return @output_port.on_failure(
              Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(
                reason: :missing_agricultural_task_id
              )
            )
          end

          user = @user_lookup.find(input_dto.user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          crop_record = @gateway.find_user_non_reference_crop_for_masters!(user, input_dto.crop_id.to_i)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, crop_record)

          begin
            task_entity = @agricultural_task_gateway.find_by_id(input_dto.agricultural_task_id)
          rescue Domain::Shared::Exceptions::RecordNotFound
            return @output_port.on_failure(
              Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(reason: :agricultural_task_not_found)
            )
          end

          unless access_filter.agricultural_task_template_associate_allows?(
            is_reference: task_entity.is_reference,
            record_user_id: task_entity.user_id
          )
            return @output_port.on_failure(
              Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(reason: :forbidden)
            )
          end

          result = @gateway.create_masters_crop_task_template_association(user, input_dto)

          if result.failure?
            @output_port.on_failure(result.failure)
          else
            @output_port.on_success(result.template)
          end
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(
            Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(
              reason: :validation_failed,
              errors: e.flatten_error_messages
            )
          )
        end
      end
    end
  end
end
