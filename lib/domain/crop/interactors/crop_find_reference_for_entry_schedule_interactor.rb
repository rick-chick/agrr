# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropFindReferenceForEntryScheduleInteractor
        def initialize(output_port:, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
        end

        def call(input)
          crop = @gateway.find_crop_record_with_stages!(input.crop_id)
          if Policies::CropReferenceRecordPolicy.visible_for_entry_schedule?(crop, region: input.region)
            @output_port.on_success(crop)
          else
            @logger.warn("[CropFindReferenceForEntryScheduleInteractor] crop not visible crop_id=#{input.crop_id.inspect}")
            @output_port.on_failure(Domain::Shared::Dtos::Error.new("Crop not found"))
          end
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
