# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class NutrientRequirementUpdateInputDto
        attr_reader :crop_id, :stage_id, :payload

        def initialize(crop_id:, stage_id:, payload:)
          @crop_id = crop_id
          @stage_id = stage_id
          @payload = payload
        end

        def self.from_hash(hash)
          new(
            crop_id: hash[:crop_id],
            stage_id: hash[:stage_id],
            payload: hash[:payload] || {}
          )
        end
      end
    end
  end
end