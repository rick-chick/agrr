# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # CultivationPlanApi を include したコントローラの非公開 find に依存する細いブリッジ。
    # Interactor に I/O 用 Proc を渡さないためのエッジ組み立て（ARCHITECTURE.md 禁止19）。
    class ApiCultivationPlanControllerPlanLoader
      def initialize(controller)
        @controller = controller
      end

      def load
        @controller.send(:find_api_cultivation_plan)
      end
    end
  end
end
