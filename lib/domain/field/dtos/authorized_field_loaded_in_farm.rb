# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      # 農場スコープで認可済みの圃場を、Gateway が一度読み込んだ結果として束ねる。
      class AuthorizedFieldLoadedInFarm
        attr_reader :field_entity, :master_form_snapshot

        def initialize(field_entity:, master_form_snapshot:)
          @field_entity = field_entity
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
