# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateCreateInteractor
        def initialize(output_port:, gateway:, crop_task_template_gateway:, user_lookup:, agricultural_task_gateway:)
          @output_port = output_port
          @gateway = gateway
          @crop_task_template_gateway = crop_task_template_gateway
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
          crop_failure = Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(reason: :crop_not_found)

          begin
            crop_entity = @gateway.find_by_id(input_dto.crop_id.to_i)
          rescue Domain::Shared::Exceptions::RecordNotFound
            return @output_port.on_failure(crop_failure)
          end

          return unless Domain::Crop::Policies::CropMastersCropEditAccess.assert_edit_or_on_failure(
            access_filter: access_filter,
            crop_entity: crop_entity,
            output_port: @output_port,
            failure: crop_failure,
          )

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

          existing = @crop_task_template_gateway.find_by_agricultural_task_id_and_crop_id(
            agricultural_task_id: input_dto.agricultural_task_id,
            crop_id: input_dto.crop_id.to_i
          )
          if Domain::Crop::Policies::MastersCropTaskTemplateCreatePolicy.duplicate?(existing_link: existing)
            return @output_port.on_failure(
              Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(reason: :duplicate)
            )
          end

          persist_attrs = Domain::Crop::Policies::MastersCropTaskTemplateCreatePolicy.build_persist_attributes(
            input_dto,
            task_entity
          )
          template_entity = @crop_task_template_gateway.create_detail(
            crop_id: input_dto.crop_id.to_i,
            agricultural_task_id: input_dto.agricultural_task_id,
            attributes: persist_attrs
          )
          masters_dto = Domain::Crop::Policies::MastersCropTaskTemplateCreatePolicy.to_masters_dto(
            template_entity,
            task_entity
          )
          @output_port.on_success(masters_dto)
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
