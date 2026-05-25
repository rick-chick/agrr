# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class NutrientRequirementActiveRecordGateway < Domain::Crop::Gateways::NutrientRequirementGateway
        include CropStageRequirementEntitySupport

        def find_by_crop_stage_id(crop_stage_id)
          requirement = ::NutrientRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement

          nutrient_requirement_entity_from_record(requirement)
        end
      end
    end
  end
end
