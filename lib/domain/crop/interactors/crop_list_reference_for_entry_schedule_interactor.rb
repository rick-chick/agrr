# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropListReferenceForEntryScheduleInteractor
        def initialize(output_port:, user_id: nil, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
          @user_id = user_id
        end

        def call(region)
          crops = []
          @gateway.each_reference_crop_for_entry_schedule(region) { |crop| crops << crop }
          @output_port.on_success(crops)
        rescue StandardError => e
          @logger.error("[CropListReferenceForEntryScheduleInteractor] #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
