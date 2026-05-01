# frozen_string_literal: true

module Domain
  module Field
    module Results
      # 農場に紐づく圃場一覧ユースケースの戻り（表現形式に依存しない）。
      class FarmFieldsList
        attr_reader :farm, :fields

        def initialize(farm:, fields:)
          @farm = farm
          @fields = fields
        end
      end
    end
  end
end
