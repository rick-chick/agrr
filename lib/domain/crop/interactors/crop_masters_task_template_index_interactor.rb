# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateIndexInteractor
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

          rows = @gateway.masters_crop_agricultural_task_templates_index_rows(crop_id: input_dto.crop_id)
          @output_port.on_success(rows)
        end
      end
    end
  end
end
