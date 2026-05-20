# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropFindReferenceForEntryScheduleInteractor
        def initialize(output_port:, user_id: nil, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
          @user_id = user_id
        end

        def call(region, crop_id)
          crop = @gateway.find_reference_crop_for_entry_schedule!(region, crop_id)
          @output_port.on_success(crop)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[CropFindReferenceForEntryScheduleInteractor] #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
