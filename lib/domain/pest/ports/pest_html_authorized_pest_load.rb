# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      # HTML 害虫編集フォーム向けの認可済みロード結果。
      class PestHtmlAuthorizedPestLoad
        attr_reader :pest_entity, :pest_master_edit_payload

        def initialize(pest_entity:, pest_master_edit_payload:)
          @pest_entity = pest_entity
          @pest_master_edit_payload = pest_master_edit_payload
        end
      end
    end
  end
end
