# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class SunshineRequirementActiveRecordGateway < Domain::Crop::Gateways::SunshineRequirementGateway
        include CropStageRequirementEntitySupport

        def find_by_crop_stage_id(crop_stage_id)
          requirement = ::SunshineRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement

          sunshine_requirement_entity_from_record(requirement)
        end
      end
    end
  end
end
