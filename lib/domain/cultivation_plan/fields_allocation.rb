# frozen_string_literal: true

require "ostruct"

module Domain
  module CultivationPlan
    # 総面積と作物リストから圃場行（面積配分）を計算する。Rails/Logger 非依存。
    class FieldsAllocation
      attr_reader :total_area, :crops

      MAX_FIELDS = 5

      def initialize(total_area, crops)
        @total_area = total_area.to_f
        @crops = Array(crops)
      end

      # @return [Array<Hash>] 各要素は { crop: crop_model_or_stub, area: Float }
      def allocate
        if total_area <= 0 || @crops.empty?
          default_crop = @crops.first || OpenStruct.new(name: "デフォルト作物", area_per_unit: 1.0)
          return [ {
            crop: default_crop,
            area: [ total_area, 100.0 ].max
          } ]
        end

        base_area = (total_area / field_count).floor
        remainder = (total_area - (base_area * field_count)).round

        prioritized_crops.map.with_index do |crop, index|
          additional_area = index < remainder ? 1.0 : 0.0

          {
            crop: crop,
            area: base_area + additional_area
          }
        end
      end

      def field_count
        @field_count ||= calculate_field_count
      end

      private

      def calculate_field_count
        max_count = [ @crops.count, MAX_FIELDS ].min

        max_count.downto(1).find do |count|
          (total_area / count) >= max_area_per_unit
        end || 1
      end

      def max_area_per_unit
        @max_area_per_unit ||= @crops.map(&:area_per_unit).compact.max || 10.0
      end

      def prioritized_crops
        @crops.sort_by { |c| -(c.area_per_unit || 0) }.take(field_count)
      end
    end
  end
end
