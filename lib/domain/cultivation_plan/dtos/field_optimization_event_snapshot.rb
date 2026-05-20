# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # REST 最適化イベント（field_added）の Action Cable `field` ペイロード。
      class FieldOptimizationEventSnapshot
        attr_reader :id, :field_id, :name, :area

        # @param id [Integer]
        # @param field_id [Integer]
        # @param name [String]
        # @param area [Numeric]
        def initialize(id:, field_id:, name:, area:)
          @id = id
          @field_id = field_id
          @name = name
          @area = area
          freeze
        end

        # @return [Hash] broadcast の `field:` に載せるキー（既存フロント契約と同一）
        def to_h
          {
            id: id,
            field_id: field_id,
            name: name,
            area: area
          }
        end
      end
    end
  end
end
