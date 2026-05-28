# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 私有計画の読み取り専用永続化（認可は Interactor + Policy。plan_id / user_id のみ）。
      class CultivationPlanPrivateReadGateway
        # @return [Domain::CultivationPlan::Dtos::PrivatePlanReadSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_plan_read_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError
        end

        # @return [Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_task_schedule_timeline_by_plan_id(plan_id:)
          raise NotImplementedError
        end

        # @return [Array<Domain::CultivationPlan::Dtos::PrivatePlanIndexPlanRow>]
        def list_private_plan_index_rows_by_user_id(user_id:)
          raise NotImplementedError
        end

        # @return [Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_optimization_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
