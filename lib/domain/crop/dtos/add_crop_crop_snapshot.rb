# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # REST add_crop: 作物解決サブステップの戻り値（plan_crop 作成・候補探索で参照するフィールドのみ）。
      class AddCropCropSnapshot
        attr_reader :id, :name, :variety, :area_per_unit, :revenue_per_area

        def initialize(id:, name:, area_per_unit:, revenue_per_area:, variety: nil)
          @id = id
          @name = name
          @variety = variety
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          freeze
        end
      end
    end
  end
end
