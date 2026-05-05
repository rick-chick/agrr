# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropListUserOwnedNonReferenceOrderedInteractor
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          crops = @gateway.list_user_owned_non_reference_crops_ordered_by_name(user)
          @output_port.on_success(crops)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[CropListUserOwnedNonReferenceOrderedInteractor] #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @logger.error("[CropListUserOwnedNonReferenceOrderedInteractor] #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
