# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropListReferenceEntitiesInteractor
        def initialize(output_port:, user_id: nil, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
          @user_id = user_id
        end

        def call(region: nil)
          crops = @gateway.list_by_is_reference(is_reference: true, region: region)
          @output_port.on_success(crops)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
