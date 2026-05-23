# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class SunshineRequirementGateway
        def find_by_crop_stage_id(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_by_crop_stage_id"
        end
      end
    end
  end
end
