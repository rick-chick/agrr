# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropDetailInteractor < Domain::Crop::Ports::CropDetailInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(crop_id)
          user = @user_lookup.find(@user_id)
          crop_entity = @gateway.find_authorized_for_view(user, crop_id)
          crop_detail_dto = Domain::Crop::Dtos::CropDetailOutputDto.new(crop: crop_entity)
          @output_port.on_success(crop_detail_dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
