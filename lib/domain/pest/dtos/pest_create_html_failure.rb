# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 害虫作成（HTML）の検証失敗時。Interactor がゲートウェイで検証済みフォームを渡す。
      class PestCreateHtmlFailure
        attr_reader :message, :master_form, :crop_ids

        def initialize(message:, master_form:, crop_ids: [])
          @message = message
          @master_form = master_form
          @crop_ids = crop_ids || []
        end
      end
    end
  end
end
