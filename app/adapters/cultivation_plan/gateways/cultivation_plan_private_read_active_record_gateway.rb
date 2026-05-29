# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanPrivateReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanPrivateReadGateway
        PlanIndexPlanSnapshot = Domain::CultivationPlan::Dtos::PlanIndexPlanSnapshot

        def find_plan_read_snapshot_by_plan_id(plan_id:)
          Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure do
            plan = CultivationPlanRestPlanPreload.find_by_plan_id(plan_id: plan_id)
            Mappers::CultivationPlanRestPlanSnapshotMapper.from_cultivation_plan(plan)
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_task_schedule_timeline_snapshot_by_plan_id(plan_id:)
          load_result = TaskScheduleTimelinePreload.load(plan_id: plan_id)
          Mappers::TaskScheduleTimelineSnapshotMapper.from_load_result(load_result)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_private_plan_index_plan_snapshots(user_id:)
          Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure do
            plans = ::CultivationPlan
                      .plan_type_private
                      .where(user_id: user_id)
                      .select(
                        :id, :status, :plan_year, :plan_name, :plan_type,
                        :total_area, :farm_id, :planning_start_date, :planning_end_date,
                        :created_at, :updated_at
                      )
                      .preload(:farm)
                      .recent
                      .to_a

            plans.group_by(&:farm_id).values.flatten.map do |plan|
              PlanIndexPlanSnapshot.new(
                id: plan.id,
                farm_display_name: plan.farm.display_name,
                total_area: plan.total_area,
                status: plan.status,
                display_name: plan.display_name,
                created_at: plan.created_at
              )
            end
          end
        end

        def count_cultivation_plan_crops_by_plan_ids(plan_ids:)
          id_list = Array(plan_ids).map(&:to_i).uniq.reject(&:zero?)
          return {} if id_list.empty?

          ::CultivationPlanCrop.where(cultivation_plan_id: id_list).group(:cultivation_plan_id).count
        end

        def count_cultivation_plan_fields_by_plan_ids(plan_ids:)
          id_list = Array(plan_ids).map(&:to_i).uniq.reject(&:zero?)
          return {} if id_list.empty?

          ::CultivationPlanField.where(cultivation_plan_id: id_list).group(:cultivation_plan_id).count
        end

        def find_optimization_plan_read_snapshot_by_plan_id(plan_id:)
          plan = ::CultivationPlan.includes(farm: :weather_location).find(plan_id)
          Mappers::OptimizationPlanReadSnapshotMapper.from_cultivation_plan(plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
