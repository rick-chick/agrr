# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class CropStageCopyGateway
        def copy_reference_stages(reference_crop_id:, new_crop_id:)
          raise NotImplementedError, "#{self.class} must implement #copy_reference_stages"
        end
      end
    end
  end
end
