# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateUpdateInteractor
        def initialize(output_port:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(input_dto.user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          failure = Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailure.new(reason: :crop_not_found)

          begin
            crop_entity = @gateway.find_by_id(input_dto.crop_id.to_i)
          rescue Domain::Shared::Exceptions::RecordNotFound
            return @output_port.on_failure(failure)
          end

          return unless Domain::Crop::Policies::CropMastersCropEditAccess.assert_edit_or_on_failure(
            access_filter: access_filter,
            crop_entity: crop_entity,
            output_port: @output_port,
            failure: failure,
          )

          result = @gateway.update_masters_crop_task_template_for_api(
            crop_id: input_dto.crop_id,
            template_id: input_dto.template_id,
            attributes: input_dto.attributes,
          )
          if result[:ok]
            @output_port.on_success(result[:row])
          else
            @output_port.on_failure(
              Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailure.new(
                reason: :validation_failed,
                errors: result[:errors]
              )
            )
          end
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(
            Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailure.new(reason: :association_not_found)
          )
        end
      end
    end
  end
end
