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
          cultivation_plan = ::CultivationPlan.includes(
            :cultivation_plan_fields,
            cultivation_plan_crops: :crop,
            field_cultivations: { cultivation_plan_crop: :crop }
          ).find(plan_id)

          plan_fields_by_id = cultivation_plan.cultivation_plan_fields.index_by(&:id)
          plan_crop_rows = cultivation_plan.cultivation_plan_crops.map do |plan_crop|
            Domain::FieldCultivation::Dtos::FieldCultivationSyncPlanCropEntry.new(
              plan_crop_id: plan_crop.id,
              crop_id: plan_crop.crop.id
            )
          end
          existing_field_cultivations_by_id = cultivation_plan.field_cultivations.index_by(&:id).transform_values do |fc|
            Domain::FieldCultivation::Dtos::FieldCultivationSyncExistingFieldCultivationEntry.new(
              field_cultivation_id: fc.id,
              cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
              crop_id: fc.cultivation_plan_crop.crop.id
            )
          end

          Domain::FieldCultivation::Dtos::FieldCultivationSyncPlanSnapshot.new(
            plan_id: cultivation_plan.id,
            plan_fields_by_id: plan_fields_by_id.transform_values(&:id),
            plan_crop_rows: plan_crop_rows,
            existing_field_cultivations_by_id: existing_field_cultivations_by_id
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

            if sync_apply.cultivation_plan_crop_ids_to_delete.any?
              @logger.info "🗑️ [FieldCultivationSync] 未参照 plan_crop 削除: " \
                            "#{sync_apply.cultivation_plan_crop_ids_to_delete.size}件"
              ::CultivationPlanCrop.where(id: sync_apply.cultivation_plan_crop_ids_to_delete).delete_all
            end

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

      end
    end
  end
end
