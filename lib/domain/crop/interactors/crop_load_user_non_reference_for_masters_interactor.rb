# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropLoadUserNonReferenceForMastersInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(crop_id)
          user = @user_lookup.find(@user_id)
          crop = @gateway.find_user_non_reference_crop_for_masters!(user, crop_id)
          @output_port.on_success(crop)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
