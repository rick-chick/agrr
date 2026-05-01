# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeLoadAuthorizedModelForEditInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(fertilize_id)
          user = @user_lookup.find(@user_id)
          fertilize = @gateway.authorized_record_for_edit(user, fertilize_id)
          @output_port.on_success(fertilize)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure
        end
      end
    end
  end
end
