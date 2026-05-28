# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust: 圃場単位の agrr current allocation 用スナップショット。
      class PlanAllocationAdjustFieldSourceSnapshot
        attr_reader :field_id, :field_name, :field_area, :cultivations

        def initialize(field_id:, field_name:, field_area:, cultivations:)
          @field_id = field_id
          @field_name = field_name
          @field_area = field_area
          @cultivations = Array(cultivations).freeze
          freeze
        end
      end
    end
  end
end
