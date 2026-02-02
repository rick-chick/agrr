# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageListInputDto
        attr_reader :crop_id

        def initialize(crop_id:)
          @crop_id = crop_id
        end

        def self.from_hash(hash)
          new(
            crop_id: hash[:crop_id]
          )
        end
      end
    end
  end
end