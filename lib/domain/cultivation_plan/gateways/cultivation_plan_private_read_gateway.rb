# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 私有計画の読み取り専用永続化（snapshot / row DTO。DTO 組立は Interactor + domain mapper）。
      class CultivationPlanPrivateReadGateway
        # @return [Object] CultivationPlanRestPlanSnapshot
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_plan_read_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError
        end

        # @return [Object] TaskScheduleTimelineSnapshot
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_task_schedule_timeline_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError
        end

        # @return [Array<Domain::CultivationPlan::Mappers::Dtos::PlanRowSnapshot>]
        def list_private_plan_index_plan_snapshots(user_id:)
          raise NotImplementedError
        end

        # @param plan_ids [Array<Integer>]
        # @return [Hash{Integer => Integer}] plan_id => crops_count
        def count_cultivation_plan_crops_by_plan_ids(plan_ids:)
          raise NotImplementedError
        end

        # @param plan_ids [Array<Integer>]
        # @return [Hash{Integer => Integer}] plan_id => fields_count
        def count_cultivation_plan_fields_by_plan_ids(plan_ids:)
          raise NotImplementedError
        end

        # @return [Object] OptimizationPlanSnapshot
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_optimization_plan_read_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
