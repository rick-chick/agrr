# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropFindReferenceForEntryScheduleInput
        attr_reader :region, :crop_id

        def initialize(region:, crop_id:)
          @region = region
          @crop_id = crop_id
        end
      end
    end
  end
end
