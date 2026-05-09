# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeLoadAuthorizedModelForViewInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(fertilize_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::FertilizePolicy.record_access_filter(user)
          bundle = @gateway.find_authorized_fertilize_loaded_bundle!(user, fertilize_id.to_i, for_edit: false, access_filter: access_filter)
          @output_port.on_success(bundle)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_permission_denied
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
