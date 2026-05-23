# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      # 農業作業マスタ HTML 作成検証失敗時（ゲートウェイが組み立てた未保存モデルをフォームへ戻す）。
      class AgriculturalTaskHtmlCreateFailure
        attr_reader :message, :task_for_form

        def initialize(message:, task_for_form:)
          @message = message
          @task_for_form = task_for_form
        end
      end
    end
  end
end
