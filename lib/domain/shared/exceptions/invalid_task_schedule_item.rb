# frozen_string_literal: true

module Domain
  module Shared
    module Exceptions
      # タスクスケジュール項目が前提を満たさない（例: GDD 必須なのに gdd_trigger が nil）。
      # アダプタ（PlanSaveSession 等）が内部エラーから変換して投げ、Interactor はこの型のみを扱う。
      class InvalidTaskScheduleItem < StandardError
      end
    end
  end
end
