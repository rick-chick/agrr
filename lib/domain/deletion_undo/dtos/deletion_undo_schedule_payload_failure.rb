# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Dtos
      # ペイロード組み立て時の失敗（例: undo トークン欠落）。ステータスは Presenter がそのまま HTTP に写す。
      class DeletionUndoSchedulePayloadFailure
        attr_reader :reason, :http_status

        def initialize(reason:, http_status: :unprocessable_entity)
          @reason = reason
          @http_status = http_status
        end
      end
    end
  end
end
