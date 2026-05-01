# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropLoadAuthorizedModelForHtmlInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(crop_id, for_edit:)
          user = @user_lookup.find(@user_id)
          crop = @gateway.load_authorized_crop_for_html(user, crop_id, for_edit: for_edit)
          @output_port.on_success(crop)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure
        end
      end
    end
  end
end
