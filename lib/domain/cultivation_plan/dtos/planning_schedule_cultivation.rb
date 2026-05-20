# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 作付計画表で表示する栽培情報（読み取り専用）
      class PlanningScheduleCultivation
        attr_reader :crop_name, :start_date, :completion_date, :area

        def initialize(crop_name:, start_date:, completion_date:, area:)
          @crop_name = crop_name
          @start_date = start_date
          @completion_date = completion_date
          @area = area
          freeze
        end
      end
    end
  end
end
