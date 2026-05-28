# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # agrr adjust / allocate 応答 Hash → domain `FieldCultivationSyncInput`（agrr キーは adapter のみ）。
      module AgrrAdjustResultFieldCultivationSyncMapper
        module_function

        # @param result [Hash]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationSyncInput]
        def to_sync_input(result)
          result = result.to_h if result.respond_to?(:to_h)
          raw_fs = pick(result, :field_schedules)
          raw_fs = [] if raw_fs.nil?

          Domain::FieldCultivation::Dtos::FieldCultivationSyncInput.new(
            field_schedules: raw_fs.map { |fs| map_field_schedule(fs) },
            optimization_summary: pick(result, :summary),
            total_profit: pick(result, :total_profit),
            total_revenue: pick(result, :total_revenue),
            total_cost: pick(result, :total_cost),
            optimization_time: pick(result, :optimization_time),
            algorithm_used: pick(result, :algorithm_used),
            is_optimal: pick(result, :is_optimal)
          )
        end

        def map_field_schedule(fs)
          fs = fs.to_h if fs.respond_to?(:to_h)
          raw_allocs = pick(fs, :allocations)
          raw_allocs = [] if raw_allocs.nil?

          Domain::FieldCultivation::Dtos::FieldCultivationSyncFieldScheduleInput.new(
            field_id: pick(fs, :field_id),
            allocations: raw_allocs.map { |alloc| map_allocation(alloc) }
          )
        end
        private_class_method :map_field_schedule

        def map_allocation(alloc)
          alloc = alloc.to_h if alloc.respond_to?(:to_h)

          Domain::FieldCultivation::Dtos::FieldCultivationSyncAllocationInput.new(
            allocation_id: pick(alloc, :allocation_id),
            external_allocation_id: pick(alloc, :id),
            crop_id: pick(alloc, :crop_id).to_s,
            start_date: pick(alloc, :start_date),
            completion_date: pick(alloc, :completion_date),
            area_used: pick(alloc, :area_used),
            area: pick(alloc, :area),
            total_cost: pick(alloc, :total_cost),
            cost: pick(alloc, :cost),
            expected_revenue: pick(alloc, :expected_revenue),
            revenue: pick(alloc, :revenue),
            profit: pick(alloc, :profit),
            accumulated_gdd: pick(alloc, :accumulated_gdd)
          )
        end
        private_class_method :map_allocation

        def pick(h, key)
          return nil unless h.is_a?(Hash)

          v = h[key.to_s]
          return v unless v.nil?

          h[key.to_sym]
        end
        private_class_method :pick
      end
    end
  end
end
