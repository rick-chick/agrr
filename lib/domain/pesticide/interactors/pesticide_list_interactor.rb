# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideListInteractor < Domain::Pesticide::Ports::PesticideListInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          filtered_pesticides = @gateway.list_from_relation(@gateway.visible_records(user))
          @output_port.on_success(filtered_pesticides)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
