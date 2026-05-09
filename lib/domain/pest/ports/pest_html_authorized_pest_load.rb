# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      # HTML 害虫編集（`form_with model: @pest`）向けの認可済みロード結果。
      #
      # `persisted_pest` の同梱は Rails フォーム都合の暫定措置。ARCHITECTURE.md の `lib/domain/` 禁止 3
      #（ユースケース境界での AR 持ち込み）を完全に満たすには、ERB/strong params を DTO 前提に移行し本フィールドを削除する（バックログ）。
      class PestHtmlAuthorizedPestLoad
        attr_reader :pest_entity, :persisted_pest

        def initialize(pest_entity:, persisted_pest:)
          @pest_entity = pest_entity
          @persisted_pest = persisted_pest
        end
      end
    end
  end
end
