# frozen_string_literal: true

module Domain
  module Pest
    module Entities
      class CropPestLinkEntity
        attr_reader :id, :crop_id, :pest_id

        def initialize(id:, crop_id:, pest_id:)
          @id = id
          @crop_id = crop_id
          @pest_id = pest_id
        end
      end
    end
  end
end
