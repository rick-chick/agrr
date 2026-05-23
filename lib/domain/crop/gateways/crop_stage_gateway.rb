# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class CropStageGateway
        def find_by_id(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end
      end
    end
  end
end
