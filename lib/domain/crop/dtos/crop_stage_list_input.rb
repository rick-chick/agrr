# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageListInput
        attr_reader :crop_id

        def initialize(crop_id:)
          @crop_id = crop_id
        end
      end
    end
  end
end
