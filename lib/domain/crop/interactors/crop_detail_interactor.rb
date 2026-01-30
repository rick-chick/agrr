# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropDetailInteractor < Domain::Crop::Ports::CropDetailInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(crop_id)
          user = User.find(@user_id)
          crop_model = Domain::Shared::Policies::CropPolicy.find_visible!(::Crop, user, crop_id)
          crop_entity = Domain::Crop::Entities::CropEntity.from_model(crop_model)
          crop_detail_dto = Domain::Crop::Dtos::CropDetailOutputDto.new(crop: crop_entity)
          @output_port.on_success(crop_detail_dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
