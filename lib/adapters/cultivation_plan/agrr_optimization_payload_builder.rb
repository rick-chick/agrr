# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # AR→最適化ペイロードの写像（ドメイン側 `AgrrOptimizationPayloadBuilder`）。
    class AgrrOptimizationPayloadBuilder
      def initialize(cultivation_plan, logger:)
        @cultivation_plan = cultivation_plan
        @logger = logger
      end

      # @param exclude_ids [Array<Integer>]
      def build_current_allocation(exclude_ids: [])
        cultivation_plan = @cultivation_plan
        @logger.info "🔍 [Build Allocation] field_cultivations count: #{cultivation_plan.field_cultivations.count}"
        @logger.info "🔍 [Build Allocation] exclude_ids: #{exclude_ids.inspect}" if exclude_ids.any?

        cultivations_by_field = cultivation_plan.field_cultivations.group_by(&:cultivation_plan_field_id)

        @logger.info "🔍 [Build Allocation] cultivations_by_field: #{cultivations_by_field.keys}"

        field_rows = []
        cultivation_plan.cultivation_plan_fields.each do |field|
          field_id = field.id
          cultivations = cultivations_by_field[field_id] || []

          filtered_cultivations = cultivations.reject { |fc| exclude_ids.include?(fc.id) }
            .select { |fc| fc.cultivation_plan_crop.crop.crop_stages.exists? }

          if exclude_ids.any?
            @logger.info "🔍 [Build Allocation] Field #{field_id}: #{cultivations.count} -> #{filtered_cultivations.count} " \
                         "(excluded: #{cultivations.count - filtered_cultivations.count})"
          end

          allocations = filtered_cultivations.map do |fc|
            revenue = fc.optimization_result&.dig("revenue") || 0.0
            cost = fc.estimated_cost || 0.0
            growth_days = fc.cultivation_days || (fc.completion_date - fc.start_date).to_i + 1
            {
              allocation_id: fc.id,
              crop_id: fc.cultivation_plan_crop.crop.id.to_s,
              crop_name: fc.crop_display_name,
              variety: fc.cultivation_plan_crop.variety,
              area_used: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              growth_days: growth_days,
              accumulated_gdd: fc.optimization_result&.dig("accumulated_gdd") || 0.0,
              total_cost: cost,
              expected_revenue: revenue
            }
          end

          field_rows << {
            field_id: field.id,
            field_name: field.name,
            field_area: field.area,
            allocations: allocations
          }
        end

        Domain::CultivationPlan::Calculators::AgrrCurrentAllocationCalculator.build(
          cultivation_plan_id: cultivation_plan.id,
          field_rows: field_rows
        )
      end

      def build_fields_config
        plan_fields = @cultivation_plan.cultivation_plan_fields.map do |field|
          {
            id: field.id.to_s,
            name: field.name,
            area: field.area,
            daily_fixed_cost: field.daily_fixed_cost
          }
        end

        Domain::CultivationPlan::Calculators::AgrrFieldsConfigCalculator.build(plan_fields: plan_fields)
      end

      def build_crops_config
        entries = @cultivation_plan.cultivation_plan_crops.map do |plan_crop|
          crop = plan_crop.crop
          has_growth_stages = crop.crop_stages.exists?
          requirement = has_growth_stages ? crop.to_agrr_requirement : nil

          {
            crop_id: crop.id.to_s,
            crop_name: crop.name,
            has_growth_stages: has_growth_stages,
            requirement: requirement
          }
        end

        Domain::CultivationPlan::Calculators::AgrrCropsConfigCalculator.build(
          entries: entries,
          logger: @logger
        )
      end

      def build_interaction_rules
        crop_groups = {}
        @cultivation_plan.cultivation_plan_crops.each do |plan_crop|
          crop = plan_crop.crop
          crop_groups[crop.id.to_s] = crop.groups
        end

        Domain::CultivationPlan::Calculators::AgrrInteractionRulesCalculator.build(
          crop_groups: crop_groups,
          random_hex: -> { SecureRandom.hex(4) }
        )
      end
    end
  end
end
