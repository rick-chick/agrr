# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 一般ユーザーによる is_reference 変更拒否（更新 HTML リダイレクト用）。
      class PestReferenceFlagChangeDenied
        attr_reader :message, :pest_id

        def initialize(message:, pest_id:)
          @message = message
          @pest_id = pest_id
        end
      end
    end
  end
end
