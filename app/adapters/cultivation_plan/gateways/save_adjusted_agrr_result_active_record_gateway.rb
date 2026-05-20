# frozen_string_literal: true

require "set"

module Adapters
  module CultivationPlan
    module Gateways
      class SaveAdjustedAgrrResultActiveRecordGateway < Domain::CultivationPlan::Gateways::SaveAdjustedAgrrResultGateway
        def initialize(logger:, clock:)
          @logger = logger
          @clock = clock
        end

        def save_adjust_result!(plan_id:, result:)
          cultivation_plan = ::CultivationPlan.find(plan_id)
          @logger.info "💾 [Save Adjusted Result] result keys: #{result.keys}"
          @logger.info "💾 [Save Adjusted Result] field_schedules: #{result[:field_schedules]&.count || 'nil'}"

          used_crop_ids = Set.new
          result[:field_schedules]&.each do |fs|
            fs["allocations"]&.each do |alloc|
              used_crop_ids.add(alloc["crop_id"])
            end
          end
          crop_by_id = ::Crop.where(id: used_crop_ids.to_a).index_by { |c| c.id.to_s }

          plan_fields_by_id = cultivation_plan.cultivation_plan_fields.index_by(&:id)
          plan_crops_by_crop_id = cultivation_plan.cultivation_plan_crops.index_by { |pc| pc.crop.id.to_s }

          all_allocation_ids = []
          result[:field_schedules]&.each do |fs|
            fs["allocations"]&.each do |alloc|
              all_allocation_ids << alloc["allocation_id"]
            end
          end

          @logger.info "💾 [Save] Total allocations in result: #{all_allocation_ids.count}"
          @logger.info "💾 [Save] Unique allocations: #{all_allocation_ids.uniq.count}"

          if all_allocation_ids.compact.count != all_allocation_ids.compact.uniq.count
            duplicates = all_allocation_ids.compact.select { |id| all_allocation_ids.count(id) > 1 }.uniq
            @logger.error "❌ [Save] CRITICAL: 重複したallocation_idが検出されました: #{duplicates}"
            @logger.error "❌ [Save] Total allocations: #{all_allocation_ids.count}, Unique(compact): #{all_allocation_ids.compact.uniq.count}"
            raise I18n.t("controllers.agrr_optimization.errors.duplicate_allocation", ids: duplicates.join(", "))
          end

          unless result[:field_schedules].present?
            @logger.error "❌ [Save Adjusted Result] CRITICAL: field_schedules is empty"
            @logger.error "❌ [Save Adjusted Result] Result keys: #{result.keys}"
            @logger.error "❌ [Save Adjusted Result] Full result: #{result.inspect}"
            raise I18n.t("controllers.agrr_optimization.errors.result_empty")
          end

          ::ActiveRecord::Base.transaction do
            cultivation_plan.reload
            now = @clock.now

            existing_fcs = cultivation_plan.field_cultivations.to_a
            existing_by_id = existing_fcs.index_by(&:id)

            desired_records = []
            result[:field_schedules].each do |field_schedule|
              field_id = field_schedule["field_id"]
              next unless field_id
              plan_field = plan_fields_by_id[field_id.to_i]
              unless plan_field
                @logger.error "❌ [Save] CRITICAL: plan_field not found for field_id: #{field_id}"
                @logger.error "❌ [Save] Available field_ids: #{cultivation_plan.cultivation_plan_fields.map(&:id)}"
                @logger.error "❌ [Save] Field schedule: #{field_schedule.inspect}"
                raise I18n.t("controllers.agrr_optimization.errors.field_missing", field_id: field_id)
              end

              next unless field_schedule["allocations"]&.present?
              field_schedule["allocations"].each do |allocation|
                crop = crop_by_id[allocation["crop_id"]]
                unless crop
                  @logger.error "❌ [Save] CRITICAL: crop not found for crop_id: #{allocation['crop_id']}"
                  @logger.error "❌ [Save] Available crop_ids: #{::Crop.pluck(:id)}"
                  @logger.error "❌ [Save] Allocation details: #{allocation.inspect}"
                  raise I18n.t("controllers.agrr_optimization.errors.crop_missing", crop_id: allocation["crop_id"])
                end

                plan_crop = plan_crops_by_crop_id[allocation["crop_id"]]
                unless plan_crop
                  @logger.error "❌ [Save] CRITICAL: plan_crop not found for crop_id: #{allocation['crop_id']}"
                  @logger.error "❌ [Save] Available crop_ids: #{cultivation_plan.cultivation_plan_crops.map { |c| c.crop.id.to_s }}"
                  @logger.error "❌ [Save] Allocation details: #{allocation.inspect}"
                  raise I18n.t("controllers.agrr_optimization.errors.plan_crop_missing", crop_id: allocation["crop_id"])
                end

                allocation_id_raw = allocation["allocation_id"] || allocation[:allocation_id] || allocation["id"] || allocation[:id]
                allocation_id = allocation_id_raw.present? ? allocation_id_raw.to_i : nil

                begin
                  start_date = Date.parse(allocation["start_date"])
                rescue ArgumentError
                  @logger.error "❌ [Save] Invalid start_date format: #{allocation['start_date'].inspect}"
                  raise ArgumentError, I18n.t("controllers.agrr_optimization.errors.start_date_invalid", value: allocation["start_date"].inspect, allocation_id: allocation_id_raw)
                end

                begin
                  completion_date = Date.parse(allocation["completion_date"])
                rescue ArgumentError
                  @logger.error "❌ [Save] Invalid completion_date format: #{allocation['completion_date'].inspect}"
                  raise ArgumentError, I18n.t("controllers.agrr_optimization.errors.completion_date_invalid", value: allocation["completion_date"].inspect, allocation_id: allocation_id_raw)
                end

                desired_records << {
                  allocation_id: allocation_id,
                  attrs: {
                    cultivation_plan_id: cultivation_plan.id,
                    cultivation_plan_field_id: plan_field.id,
                    cultivation_plan_crop_id: plan_crop.id,
                    start_date: start_date,
                    completion_date: completion_date,
                    cultivation_days: (completion_date - start_date).to_i + 1,
                    area: allocation["area_used"] || allocation["area"],
                    estimated_cost: allocation["total_cost"] || allocation["cost"],
                    optimization_result: {
                      revenue: allocation["expected_revenue"] || allocation["revenue"],
                      profit: allocation["profit"],
                      accumulated_gdd: allocation["accumulated_gdd"]
                    },
                    updated_at: now,
                    created_at: now
                  }
                }
              end
            end

            desired_with_existing = desired_records.select { |r| r[:allocation_id].present? && existing_by_id.key?(r[:allocation_id]) }
            to_update = desired_with_existing
            to_create = desired_records.reject { |r| r[:allocation_id].present? && existing_by_id.key?(r[:allocation_id]) }

            desired_existing_ids = desired_with_existing.map { |r| r[:allocation_id] }
            to_delete_ids = existing_by_id.keys - desired_existing_ids

            @logger.info "🛠️ [Save] to_update: #{to_update.size}, to_create: #{to_create.size}, to_delete: #{to_delete_ids.size}"

            if to_update.any?
              upsert_rows = to_update.map do |rec|
                rec[:attrs].except(:created_at).merge(id: rec[:allocation_id])
              end
              ::FieldCultivation.upsert_all(upsert_rows, unique_by: [ :id ])
            end

            if to_create.any?
              insert_rows = to_create.map { |r| r[:attrs] }
              ::FieldCultivation.insert_all!(insert_rows)
            end

            if to_delete_ids.any?
              ::TaskSchedule.where(field_cultivation_id: to_delete_ids).update_all(field_cultivation_id: nil)
              ::FieldCultivation.where(id: to_delete_ids).delete_all
            end

            if used_crop_ids.any?
              used_plan_crop_ids = cultivation_plan.cultivation_plan_crops.select { |pc| used_crop_ids.include?(pc.crop.id.to_s) }.map(&:id)
              unused_plan_crops = cultivation_plan.cultivation_plan_crops.where.not(id: used_plan_crop_ids)
              if unused_plan_crops.exists?
                @logger.info "🗑️ [Save] 使われていない作物を削除: #{unused_plan_crops.pluck(:name).join(', ')}"
                unused_plan_crops.delete_all
              end
            end

            cultivation_plan.update!(
              optimization_summary: result[:summary],
              total_profit: result[:total_profit],
              total_revenue: result[:total_revenue],
              total_cost: result[:total_cost],
              optimization_time: result[:optimization_time],
              algorithm_used: result[:algorithm_used],
              is_optimal: result[:is_optimal],
              status: "completed"
            )

            final_count = cultivation_plan.field_cultivations.count
            @logger.info "📊 [Save] トランザクション完了: 最終的なfield_cultivations件数 = #{final_count}"
          end
        end
      end
    end
  end
end
