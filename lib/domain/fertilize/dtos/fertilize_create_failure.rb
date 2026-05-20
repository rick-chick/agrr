# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # 肥料作成（HTML）の検証失敗時。Interactor がゲートウェイで検証済みフォームを渡す。
      class FertilizeCreateFailure
        attr_reader :message, :master_form

        def initialize(message:, master_form:)
          @message = message
          @master_form = master_form
        end
      end
    end
  end
end
