# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # adjust 前の生育段階有無チェック用（計画作物ごと）。
      class CultivationPlanAdjustCropGrowthRow
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
