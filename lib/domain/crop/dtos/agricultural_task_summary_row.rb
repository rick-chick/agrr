# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 作物詳細の農業タスク選択 UI 用の最小行（ActiveRecord をビューに渡さない）。
      class AgriculturalTaskSummaryRow
        attr_reader :id, :name, :description

        def initialize(id:, name:, description: nil)
          @id = id
          @name = name
          @description = description
        end
      end
    end
  end
end
