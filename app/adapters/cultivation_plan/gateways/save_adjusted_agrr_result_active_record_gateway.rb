# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class SaveAdjustedAgrrResultActiveRecordGateway < Domain::CultivationPlan::Gateways::SaveAdjustedAgrrResultGateway
        def initialize(logger:, clock:)
          @logger = logger
          @clock = clock
        end

        def load_persist_context(plan_id:)
          cultivation_plan = ::CultivationPlan.find(plan_id)
          plan_fields_by_id = cultivation_plan.cultivation_plan_fields.index_by(&:id)
          plan_crops_by_crop_id = cultivation_plan.cultivation_plan_crops.index_by { |pc| pc.crop.id.to_s }

          Domain::CultivationPlan::Dtos::SaveAdjustedAgrrPersistContext.new(
            plan_id: cultivation_plan.id,
            plan_fields_by_id: plan_fields_by_id.transform_values(&:id),
            plan_crops_by_crop_id: plan_crops_by_crop_id.transform_values(&:id),
            existing_field_cultivation_ids: cultivation_plan.field_cultivations.pluck(:id)
          )
        end

        def apply_persist_bundle!(plan_id:, bundle:)
          cultivation_plan = ::CultivationPlan.find(plan_id)
          @logger.info "💾 [Save Adjusted Result] upserts=#{bundle.upserts.size} creates=#{bundle.creates.size} " \
                        "deletes=#{bundle.delete_field_cultivation_ids.size}"

          ::ActiveRecord::Base.transaction do
            cultivation_plan.reload
            now = @clock.now

            if bundle.upserts.any?
              upsert_rows = bundle.upserts.map do |rec|
                row_attrs(rec, cultivation_plan_id: cultivation_plan.id, now: now).except(:created_at).merge(id: rec.field_cultivation_id)
              end
              ::FieldCultivation.upsert_all(upsert_rows, unique_by: [ :id ])
            end

            if bundle.creates.any?
              insert_rows = bundle.creates.map do |rec|
                row_attrs(rec, cultivation_plan_id: cultivation_plan.id, now: now)
              end
              ::FieldCultivation.insert_all!(insert_rows)
            end

            if bundle.delete_field_cultivation_ids.any?
              ::TaskSchedule.where(field_cultivation_id: bundle.delete_field_cultivation_ids).update_all(field_cultivation_id: nil)
              ::FieldCultivation.where(id: bundle.delete_field_cultivation_ids).delete_all
            end

            delete_unused_plan_crops!(cultivation_plan, bundle.used_crop_ids)

            summary = bundle.plan_summary
            cultivation_plan.update!(
              optimization_summary: summary.summary,
              total_profit: summary.total_profit,
              total_revenue: summary.total_revenue,
              total_cost: summary.total_cost,
              optimization_time: summary.optimization_time,
              algorithm_used: summary.algorithm_used,
              is_optimal: summary.is_optimal,
              status: summary.status
            )

            @logger.info "📊 [Save] トランザクション完了: field_cultivations=#{cultivation_plan.field_cultivations.count}"
          end
        end

        private

        def row_attrs(rec, cultivation_plan_id:, now:)
          {
            cultivation_plan_id: cultivation_plan_id,
            cultivation_plan_field_id: rec.cultivation_plan_field_id,
            cultivation_plan_crop_id: rec.cultivation_plan_crop_id,
            start_date: rec.start_date,
            completion_date: rec.completion_date,
            cultivation_days: rec.cultivation_days,
            area: rec.area,
            estimated_cost: rec.estimated_cost,
            optimization_result: rec.optimization_result,
            updated_at: now,
            created_at: now
          }
        end

        def delete_unused_plan_crops!(cultivation_plan, used_crop_ids)
          return if used_crop_ids.empty?

          used_plan_crop_ids = cultivation_plan.cultivation_plan_crops.select do |pc|
            used_crop_ids.include?(pc.crop.id.to_s)
          end.map(&:id)
          unused_plan_crops = cultivation_plan.cultivation_plan_crops.where.not(id: used_plan_crop_ids)
          return unless unused_plan_crops.exists?

          @logger.info "🗑️ [Save] 使われていない作物を削除: #{unused_plan_crops.pluck(:name).join(', ')}"
          unused_plan_crops.delete_all
        end
      end
    end
  end
end
