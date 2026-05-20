# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr fields 設定（読み取り）。
      class AdjustWithDbWeatherFieldsConfig
        attr_reader :rows

        # @param rows [Array<AdjustWithDbWeatherFieldConfigRow>]
        def initialize(rows:)
          @rows = rows.freeze
          freeze
        end

        # @param array [Array<Hash>] AgrrFieldsConfigCalculator の戻り
        # @return [AdjustWithDbWeatherFieldsConfig]
        def self.from_fields_array(array)
          rows = Array(array).map { |h| AdjustWithDbWeatherFieldConfigRow.from_hash(h) }
          new(rows: rows)
        end

        def empty?
          rows.empty?
        end
      end
    end
  end
end
