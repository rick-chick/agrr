# frozen_string_literal: true

module Domain
  module Field
    module Results
      # 圃場詳細ユースケースの戻り: 認可済み農場コンテキスト付き（表現形式に依存しない）。
      class FieldWithFarm
        attr_reader :farm, :field

        def initialize(farm:, field:)
          @farm = farm
          @field = field
        end
      end
    end
  end
end
