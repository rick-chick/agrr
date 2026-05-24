# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 圃場単位の adjust 用読み取り行（allocations は source cultivation 行）。
      class AgrrAdjustFieldSourceRow
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
