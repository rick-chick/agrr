# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class NutrientRequirementEntity
        attr_reader :id, :crop_stage_id, :daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :region

        def initialize(attributes)
          @id = attributes[:id]
          @crop_stage_id = attributes[:crop_stage_id]
          @daily_uptake_n = attributes[:daily_uptake_n]
          @daily_uptake_p = attributes[:daily_uptake_p]
          @daily_uptake_k = attributes[:daily_uptake_k]
          @region = attributes[:region]

          validate!
        end

        # ActiveRecordモデルからの変換
        def self.from_model(model)
          new(
            id: model.id,
            crop_stage_id: model.crop_stage_id,
            daily_uptake_n: model.daily_uptake_n,
            daily_uptake_p: model.daily_uptake_p,
            daily_uptake_k: model.daily_uptake_k,
            region: model.region
          )
        end

        private

        def validate!
          raise ArgumentError, "Crop stage ID is required" if crop_stage_id.blank?
        end
      end
    end
  end
end