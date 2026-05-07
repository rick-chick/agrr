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
          rows = @gateway.selectable_agricultural_task_picklist_rows_for_nested_templates(
            user: user,
            crop_id: input_dto.crop_id
          )
          @output_port.on_success(rows)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(
            Domain::Crop::Dtos::MastersCropTaskTemplateMastersApiFailureDto.new(reason: :crop_not_found)
          )
        end
      end
    end
  end
end
