# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      class AddCropCropResolvePrivate < Domain::CultivationPlan::Ports::AddCropCropResolveInputPort
        def initialize(crop_gateway:, user_id:, user_lookup:, logger:)
          @crop_gateway = crop_gateway
          @user_id = user_id
          @user_lookup = user_lookup
          @logger = logger
        end

        def call(crop_id:)
          collector = AddCropCropResolveCollector.new
          Domain::Crop::Interactors::CropFindUserNonReferenceRecordInteractor.new(
            output_port: collector,
            user_id: @user_id,
            gateway: @crop_gateway,
            logger: @logger,
            user_lookup: @user_lookup
          ).call(crop_id)
          source = collector.resolved_crop
          source ? Adapters::Crop::Mappers::AddCropCropSnapshotMapper.from_source(source) : nil
        end
      end
    end
  end
end
