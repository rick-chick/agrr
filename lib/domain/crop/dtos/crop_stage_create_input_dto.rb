# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageCreateInputDto
        attr_reader :crop_id, :payload

        def initialize(crop_id:, payload:)
          @crop_id = crop_id
          @payload = payload
        end

        def self.from_hash(hash)
          new(
            crop_id: hash[:crop_id],
            payload: hash[:payload] || {}
          )
        end
      end
    end
  end
end