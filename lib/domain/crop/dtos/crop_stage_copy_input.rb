# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageCopyInput
        attr_reader :reference_crop_id, :new_crop_id

        def initialize(reference_crop_id:, new_crop_id:)
          @reference_crop_id = reference_crop_id
          @new_crop_id = new_crop_id
        end
      end
    end
  end
end
