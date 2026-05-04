# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      # 農場スコープで認可済みの圃場を、Gateway が一度読み込んだ結果として束ねる。
      class AuthorizedFieldLoadedInFarmDto
        attr_reader :field_entity, :persisted_field

        def initialize(field_entity:, persisted_field:)
          @field_entity = field_entity
          @persisted_field = persisted_field
        end
      end
    end
  end
end
