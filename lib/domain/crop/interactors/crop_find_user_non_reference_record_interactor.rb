# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropFindUserNonReferenceRecordInteractor
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(crop_id)
          user = @user_lookup.find(@user_id)
          crop = @gateway.find_user_non_reference_crop_record(user, crop_id)
          @output_port.on_success(crop)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[CropFindUserNonReferenceRecordInteractor] #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
