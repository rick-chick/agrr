# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存: 参照計画上の作物 1 行（ステージは含めない）。
      class PublicPlanSaveCropReferenceRow
        attr_reader :cultivation_plan_crop_id, :reference_crop_id, :name, :variety,
                    :area_per_unit, :revenue_per_area, :groups, :region

        # @param cultivation_plan_crop_id [Integer]
        # @param reference_crop_id [Integer]
        # @param name [String]
        # @param variety [String, nil]
        # @param area_per_unit [Numeric, nil]
        # @param revenue_per_area [Numeric, nil]
        # @param groups [Array<String>, nil]
        # @param region [String, nil]
        def initialize(
          cultivation_plan_crop_id:,
          reference_crop_id:,
          name:,
          variety: nil,
          area_per_unit: nil,
          revenue_per_area: nil,
          groups: nil,
          region: nil
        )
          @cultivation_plan_crop_id = cultivation_plan_crop_id.to_i
          @reference_crop_id = reference_crop_id.to_i
          @name = name.nil? ? nil : name.to_s
          @variety = variety
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @groups = groups
          @region = region
          freeze
        end
      end
    end
  end
end
