# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # adjust 生育段階ゲート用の計画作物スナップショット（永続層からの読取のみ）。
      class CultivationPlanAdjustPlanCropGrowthSnapshot
        attr_reader :crop_name, :growth_stage_count

        def initialize(crop_name:, growth_stage_count:)
          @crop_name = crop_name
          @growth_stage_count = growth_stage_count
          freeze
        end
      end
    end
  end
end
