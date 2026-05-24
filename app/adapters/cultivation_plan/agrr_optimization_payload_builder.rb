# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # AR 読み取りと daemon 向け JSON 組み立て。ビジネス行の写像は domain mapper。
    class AgrrOptimizationPayloadBuilder
      def initialize(cultivation_plan, logger:, crop_agrr_requirement_builder:)
        @cultivation_plan = cultivation_plan
        @logger = logger
        @crop_agrr_requirement_builder = crop_agrr_requirement_builder
      end

      # @param exclude_ids [Array<Integer>]
      def build_current_allocation(exclude_ids: [])
        @logger.info "🔍 [Build Allocation] field_cultivations count: #{@cultivation_plan.field_cultivations.count}"
        @logger.info "🔍 [Build Allocation] exclude_ids: #{exclude_ids.inspect}" if exclude_ids.any?

        field_rows = adjust_field_source_rows
        Domain::CultivationPlan::Mappers::AgrrAdjustAllocationRowMapper.build_current_allocation(
          cultivation_plan_id: @cultivation_plan.id,
          field_rows: field_rows,
          exclude_ids: exclude_ids
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
          requirement = has_growth_stages ? @crop_agrr_requirement_builder.build_from(crop) : nil

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

      private

      def adjust_field_source_rows
        cultivations_by_field = @cultivation_plan.field_cultivations.group_by(&:cultivation_plan_field_id)

        @cultivation_plan.cultivation_plan_fields.map do |field|
          cultivations = cultivations_by_field[field.id] || []
          source_rows = cultivations.map { |fc| field_cultivation_source_row(fc) }

          Domain::CultivationPlan::Dtos::AgrrAdjustFieldSourceRow.new(
            field_id: field.id,
            field_name: field.name,
            field_area: field.area,
            cultivations: source_rows
          )
        end
      end

      def field_cultivation_source_row(fc)
        crop = fc.cultivation_plan_crop.crop
        revenue = fc.optimization_result&.dig("revenue") || 0.0

        Domain::CultivationPlan::Dtos::AgrrAdjustFieldCultivationSourceRow.new(
          field_cultivation_id: fc.id,
          field_id: fc.cultivation_plan_field_id,
          crop_id: crop.id,
          crop_name: fc.crop_display_name,
          variety: fc.cultivation_plan_crop.variety,
          area: fc.area,
          start_date: fc.start_date,
          completion_date: fc.completion_date,
          cultivation_days: fc.cultivation_days || ((fc.completion_date - fc.start_date).to_i + 1),
          estimated_cost: fc.estimated_cost || 0.0,
          revenue: revenue,
          accumulated_gdd: fc.optimization_result&.dig("accumulated_gdd") || 0.0,
          has_growth_stages: crop.crop_stages.exists?
        )
      end
    end
  end
end
