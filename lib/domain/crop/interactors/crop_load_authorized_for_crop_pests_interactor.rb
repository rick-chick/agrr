# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropLoadAuthorizedForCropPestsInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(crop_id)
          user = @user_lookup.find(@user_id)
          crop = @gateway.find_model(crop_id.to_i)
          unless crop.is_reference || crop.user_id == user.id
            return @output_port.on_failure(:no_permission)
          end
          @output_port.on_success(crop)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(:no_permission)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(:not_found)
        end
      end
    end
  end
end
