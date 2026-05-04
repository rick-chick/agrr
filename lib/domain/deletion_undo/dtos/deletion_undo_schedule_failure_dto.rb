# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Dtos
      # スケジュール失敗の種別を Presenter／I18n 写像用に保持する。
      class DeletionUndoScheduleFailureDto
        attr_reader :reason, :detail_message

        def initialize(reason:, detail_message: nil)
          @reason = reason
          @detail_message = detail_message
        end
      end
    end
  end
end
