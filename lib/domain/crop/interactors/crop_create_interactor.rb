# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropCreateInteractor < Domain::Crop::Ports::CropCreateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto)
          user = User.find(@user_id)
          crop_model = Domain::Shared::Policies::CropPolicy.build_for_create(::Crop, user, {
            name: input_dto.name,
            variety: input_dto.variety,
            area_per_unit: input_dto.area_per_unit,
            revenue_per_area: input_dto.revenue_per_area,
            region: input_dto.region,
            groups: input_dto.groups || []
          })
          raise StandardError, crop_model.errors.full_messages.join(', ') unless crop_model.save

          crop_entity = Domain::Crop::Entities::CropEntity.from_model(crop_model)
          @output_port.on_success(crop_entity)
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end


