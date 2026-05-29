# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropShowDetailNutrientRequirementSnapshot
        attr_reader :id, :crop_stage_id, :daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :region

        def initialize(id:, crop_stage_id:, daily_uptake_n:, daily_uptake_p:, daily_uptake_k:, region:)
          @id = id
          @crop_stage_id = crop_stage_id
          @daily_uptake_n = daily_uptake_n
          @daily_uptake_p = daily_uptake_p
          @daily_uptake_k = daily_uptake_k
          @region = region
          freeze
        end
      end
    end
  end
end
