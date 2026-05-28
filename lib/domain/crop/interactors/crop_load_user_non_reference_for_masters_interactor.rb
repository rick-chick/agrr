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
          crop_entity = @gateway.find_by_id(crop_id)
          Policies::CropMastersNestedAccess.assert_edit_allowed_for_masters!(user, crop_entity)
          @output_port.on_success(crop_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_not_found
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
