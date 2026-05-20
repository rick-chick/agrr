# frozen_string_literal: true

module Adapters
  module Application
    # `plan_path(plan_id)` をコントローラの view_context から提供（Presenter / Dispatcher へのルート注入）。
    class PlanPathRoutesFromController
      def initialize(controller)
        @controller = controller
      end

      def plan_path(plan_id)
        @controller.view_context.plan_path(plan_id)
      end
    end
  end
end
