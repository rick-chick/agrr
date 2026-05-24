# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationGateway
        # 認可は Interactor（PlanFieldCultivationAccess）。計画コンテキストのみ返す。
        def find_plan_access_context(field_cultivation_id)
          raise NotImplementedError, "Subclasses must implement find_plan_access_context"
        end

        def find_api_summary(field_cultivation_id:)
          raise NotImplementedError, "Subclasses must implement find_api_summary"
        end

        def update_field_cultivation_schedule(field_cultivation_id:, start_date:, completion_date:, public_plan: false)
          raise NotImplementedError, "Subclasses must implement update_field_cultivation_schedule"
        end
      end
    end
  end
end
