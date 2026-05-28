# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationSyncActiveRecordGateway < Domain::FieldCultivation::Gateways::FieldCultivationSyncGateway
        def initialize(logger:, clock:)
          @logger = logger
          @clock = clock
        end

        def find_sync_plan_snapshot_by_plan_id(plan_id:)
          cultivation_plan = ::CultivationPlan.find(plan_id)
          plan_fields_by_id = cultivation_plan.cultivation_plan_fields.index_by(&:id)
          plan_crops_by_crop_id = cultivation_plan.cultivation_plan_crops.index_by { |pc| pc.crop.id.to_s }

          Domain::FieldCultivation::Dtos::FieldCultivationSyncPlanSnapshot.new(
            plan_id: cultivation_plan.id,
            plan_fields_by_id: plan_fields_by_id.transform_values(&:id),
            plan_crops_by_crop_id: plan_crops_by_crop_id.transform_values(&:id),
            existing_field_cultivation_ids: cultivation_plan.field_cultivations.pluck(:id)
          )
        end

        def sync_by_plan_id(plan_id:, sync_apply:)
          cultivation_plan = ::CultivationPlan.find(plan_id)
          @logger.info "💾 [FieldCultivationSync] updates=#{sync_apply.field_cultivations_to_update.size} " \
                        "creates=#{sync_apply.field_cultivations_to_create.size} " \
                        "deletes=#{sync_apply.field_cultivation_ids_to_delete.size}"

          ::ActiveRecord::Base.transaction do
            cultivation_plan.reload
            now = @clock.now

            if sync_apply.field_cultivations_to_update.any?
              upsert_rows = sync_apply.field_cultivations_to_update.map do |row|
                field_cultivation_row_attributes(
                  row,
                  cultivation_plan_id: cultivation_plan.id,
                  now: now
                ).except(:created_at).merge(id: row.field_cultivation_id)
              end
              ::FieldCultivation.upsert_all(upsert_rows, unique_by: [ :id ])
            end

            if sync_apply.field_cultivations_to_create.any?
              insert_rows = sync_apply.field_cultivations_to_create.map do |row|
                field_cultivation_row_attributes(row, cultivation_plan_id: cultivation_plan.id, now: now)
              end
              ::FieldCultivation.insert_all!(insert_rows)
            end

            if sync_apply.field_cultivation_ids_to_delete.any?
              ::TaskSchedule.where(field_cultivation_id: sync_apply.field_cultivation_ids_to_delete)
                            .update_all(field_cultivation_id: nil)
              ::FieldCultivation.where(id: sync_apply.field_cultivation_ids_to_delete).delete_all
            end

            delete_unreferenced_plan_crops!(cultivation_plan, sync_apply.referenced_crop_ids)

            summary = sync_apply.cultivation_plan_summary
            cultivation_plan.update!(
              optimization_summary: summary.optimization_summary,
              total_profit: summary.total_profit,
              total_revenue: summary.total_revenue,
              total_cost: summary.total_cost,
              optimization_time: summary.optimization_time,
              algorithm_used: summary.algorithm_used,
              is_optimal: summary.is_optimal,
              status: summary.status
            )

            @logger.info "📊 [FieldCultivationSync] 完了: field_cultivations=#{cultivation_plan.field_cultivations.count}"
          end
        end

        private

        def field_cultivation_row_attributes(row, cultivation_plan_id:, now:)
          {
            cultivation_plan_id: cultivation_plan_id,
            cultivation_plan_field_id: row.cultivation_plan_field_id,
            cultivation_plan_crop_id: row.cultivation_plan_crop_id,
            start_date: row.start_date,
            completion_date: row.completion_date,
            cultivation_days: row.cultivation_days,
            area: row.area,
            estimated_cost: row.estimated_cost,
            optimization_result: row.optimization_result,
            updated_at: now,
            created_at: now
          }
        end

        def delete_unreferenced_plan_crops!(cultivation_plan, referenced_crop_ids)
          return if referenced_crop_ids.empty?

          retained_plan_crop_ids = cultivation_plan.cultivation_plan_crops.select do |pc|
            referenced_crop_ids.include?(pc.crop.id.to_s)
          end.map(&:id)
          unreferenced_plan_crops = cultivation_plan.cultivation_plan_crops.where.not(id: retained_plan_crop_ids)
          return unless unreferenced_plan_crops.exists?

          @logger.info "🗑️ [FieldCultivationSync] 未参照 plan_crop 削除: #{unreferenced_plan_crops.pluck(:name).join(', ')}"
          unreferenced_plan_crops.delete_all
        end
      end
    end
  end
end
