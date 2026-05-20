# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存セッションの圃場スナップショット 1 行。
      class PublicPlanSaveFieldDatum
        attr_reader :name, :area, :coordinates

        # @param row [Hash, PublicPlanSaveFieldDatum]
        # @return [PublicPlanSaveFieldDatum, nil]
        def self.from_row(row)
          return row if row.is_a?(PublicPlanSaveFieldDatum)
          return nil unless row.is_a?(Hash)

          new(
            name: fetch_key(row, :name),
            area: fetch_key(row, :area),
            coordinates: Array(fetch_key(row, :coordinates))
          )
        end

        # @param name [String, Numeric, nil]
        # @param area [Numeric, String, nil]
        # @param coordinates [Array]
        def initialize(name:, area:, coordinates: [])
          @name = name.nil? ? nil : name.to_s
          @area = area
          @coordinates = coordinates.freeze
          freeze
        end

        # @return [Hash]
        def to_session_row
          { name: name, area: area, coordinates: coordinates }
        end

        def self.fetch_key(h, key)
          sym = key.to_sym
          str = key.to_s
          h[sym] || h[str]
        end
        private_class_method :fetch_key
      end
    end
  end
end
