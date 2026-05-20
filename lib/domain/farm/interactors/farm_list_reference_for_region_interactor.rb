# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmListReferenceForRegionInteractor
        def initialize(output_port:, user_id: nil, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
          @user_id = user_id
        end

        def call(region)
          farms = @gateway.list_reference_farms_for_region(region)
          @output_port.on_success(farms)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error("[FarmListReferenceForRegionInteractor] #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
