# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # REST GET data（ワークベンチ JSON）の組み立て結果。
      class CultivationPlanWorkbenchPayloadOutput
        attr_reader :kind, :body, :message

        def initialize(kind:, body: nil, message: nil)
          @kind = kind
          @body = body
          @message = message
        end
      end
    end
  end
end
