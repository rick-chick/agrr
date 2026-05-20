# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Presenter が Symbol ステータスで render_response するための失敗ペイロード
      class PrivatePlanInitializeFromSelectionFailure
        attr_reader :http_status, :message

        def initialize(http_status:, message:)
          @http_status = http_status
          @message = message
        end
      end
    end
  end
end
