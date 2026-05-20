# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr crops 設定（読み取り）。
      class AdjustWithDbWeatherCropConfigs
        attr_reader :rows

        # @param rows [Array<AdjustWithDbWeatherCropConfigRow>]
        def initialize(rows:)
          @rows = rows.freeze
          freeze
        end

        # @param array [Array<Hash>] AgrrCropsConfigCalculator の戻り
        # @return [AdjustWithDbWeatherCropConfigs]
        def self.from_crops_array(array)
          rows = Array(array).map { |h| AdjustWithDbWeatherCropConfigRow.from_hash(h) }
          new(rows: rows)
        end

        def empty?
          rows.empty?
        end
      end
    end
  end
end
