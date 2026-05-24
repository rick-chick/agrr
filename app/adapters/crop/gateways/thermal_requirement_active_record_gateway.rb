# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class ThermalRequirementMemoryGateway < Domain::Crop::Gateways::ThermalRequirementGateway
        include CropStageRequirementEntitySupport

        def find_by_crop_stage_id(crop_stage_id)
          requirement = ::ThermalRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement

          thermal_requirement_entity_from_record(requirement)
        end
      end
    end
  end
end
