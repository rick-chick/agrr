# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideLoadAuthorizedModelForViewInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(pesticide_id)
          user = @user_lookup.find(@user_id)
          pesticide = @gateway.find_authorized_model_for_view(user, pesticide_id)
          @output_port.on_success(pesticide)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure
        end
      end
    end
  end
end
