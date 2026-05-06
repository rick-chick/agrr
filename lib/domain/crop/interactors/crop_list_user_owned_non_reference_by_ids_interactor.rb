# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropListUserOwnedNonReferenceByIdsInteractor
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(crop_ids)
          user = @user_lookup.find(@user_id)
          crops = @gateway.list_user_owned_non_reference_crops_by_ids(user, crop_ids)
          @output_port.on_success(crops)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[CropListUserOwnedNonReferenceByIdsInteractor] #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
