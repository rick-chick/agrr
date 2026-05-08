# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      # セッション起点の私有計画作成 (`PlansController#create`) の出力コールバック。
      class PrivatePlanCreateFromSessionOutputPort
        def on_missing_session
          raise NotImplementedError, "Subclasses must implement on_missing_session"
        end

        def on_restart
          raise NotImplementedError, "Subclasses must implement on_restart"
        end

        def on_no_crops_selected
          raise NotImplementedError, "Subclasses must implement on_no_crops_selected"
        end

        def on_existing_plan(plan_id:, plan_year:)
          raise NotImplementedError, "Subclasses must implement on_existing_plan"
        end

        def on_initialize_failed(message:)
          raise NotImplementedError, "Subclasses must implement on_initialize_failed"
        end

        def on_success(plan_id:)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
