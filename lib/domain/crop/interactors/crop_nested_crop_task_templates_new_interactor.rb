# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropNestedCropTaskTemplatesNewInteractor
        def initialize(output_port:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(input_dto.user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          failure = Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailure.new(reason: :crop_not_found)
          return unless Domain::Crop::Policies::CropMastersCropEditAccess.assert_edit_or_on_failure(
            access_filter: access_filter,
            crop_id: input_dto.crop_id.to_i,
            gateway: @gateway,
            output_port: @output_port,
            failure: failure,
          )

          rows = @gateway.selectable_agricultural_task_picklist_rows_for_nested_templates(
            user: user,
            crop_id: input_dto.crop_id,
          )
          @output_port.on_success(rows)
        end
      end
    end
  end
end
