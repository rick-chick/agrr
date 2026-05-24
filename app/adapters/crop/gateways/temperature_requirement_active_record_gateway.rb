# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class TemperatureRequirementMemoryGateway < Domain::Crop::Gateways::TemperatureRequirementGateway
        include CropStageRequirementEntitySupport

        def find_by_crop_stage_id(crop_stage_id)
          requirement = ::TemperatureRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement

          temperature_requirement_entity_from_record(requirement)
        end
      end
    end
  end
end
