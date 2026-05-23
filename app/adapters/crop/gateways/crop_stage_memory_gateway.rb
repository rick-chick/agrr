# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropStageMemoryGateway < Domain::Crop::Gateways::CropStageGateway
        include CropStageRequirementEntitySupport

        def find_by_id(crop_stage_id)
          crop_stage = ::CropStage.find(crop_stage_id)
          crop_stage_entity_from_record(crop_stage)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end
      end
    end
  end
end
