# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmLoadAuthorizedModelForEditInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(farm_id)
          user = @user_lookup.find(@user_id)
          farm = @gateway.find_authorized_model_for_edit(user, farm_id)
          @output_port.on_success(farm)
        rescue ::PolicyPermissionDenied, Domain::Shared::Policies::PolicyPermissionDenied, Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure
        end
      end
    end
  end
end
