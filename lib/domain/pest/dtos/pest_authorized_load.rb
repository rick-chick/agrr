# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # HTML 害虫編集フォーム向けの認可済みロード結果。
      class PestAuthorizedLoad
        attr_reader :pest_master_edit_payload, :html_display

        def initialize(pest_master_edit_payload:, html_display: nil)
          @pest_master_edit_payload = pest_master_edit_payload
          @html_display = html_display
        end
      end
    end
  end
end
