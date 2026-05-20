# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # 作付計画表など HTML 選択 UI 用の最小行（ActiveRecord を渡さない）
      class FarmIdName
        attr_reader :id, :name

        def initialize(id:, name:)
          @id = id
          @name = name
        end
      end
    end
  end
end
