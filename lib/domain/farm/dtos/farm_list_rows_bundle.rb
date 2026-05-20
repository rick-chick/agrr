# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # 農場一覧（カード／行 DTO 束）: Output Port に渡すデータ（AR 禁止）。
      class FarmListRowsBundle
        attr_reader :farm_rows, :reference_farm_rows

        def initialize(farm_rows:, reference_farm_rows:)
          @farm_rows = farm_rows
          @reference_farm_rows = reference_farm_rows
        end
      end
    end
  end
end
