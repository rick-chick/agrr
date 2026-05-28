# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      # Read snapshot から agrr daemon 投入用ペイロードを組み立てる（I/O なし）。
      module PlanAllocationAdjustAgrrPayloadMapper
        module_function

        # @param snapshot [Dtos::PlanAllocationAdjustReadSnapshot]
        # @param exclude_ids [Array<Integer>]
        # @param logger [#info]
        def to_current_allocation(snapshot:, exclude_ids: [], logger:)
          field_cultivation_count = snapshot.field_source_snapshots.sum { |field| field.cultivations.size }
          logger.info "🔍 [Build Allocation] field_cultivations count: #{field_cultivation_count}"
          logger.info "🔍 [Build Allocation] exclude_ids: #{exclude_ids.inspect}" if exclude_ids.any?

          AgrrAdjustAllocationRowMapper.build_current_allocation(
            cultivation_plan_id: snapshot.plan_id,
            field_snapshots: snapshot.field_source_snapshots,
            exclude_ids: exclude_ids
          )
        end

        # @param snapshot [Dtos::PlanAllocationAdjustReadSnapshot]
        def to_fields_config(snapshot:)
          plan_fields = snapshot.plan_field_snapshots.map do |field|
            {
              id: field.id.to_s,
              name: field.name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            }
          end

          Calculators::AgrrFieldsConfigCalculator.build(plan_fields: plan_fields)
        end

        # @param snapshot [Dtos::PlanAllocationAdjustReadSnapshot]
        # @param logger [#info]
        def to_crops_config(snapshot:, logger:)
          entries = snapshot.plan_crop_snapshots.map do |entry|
            {
              crop_id: entry.crop_id.to_s,
              crop_name: entry.crop_name,
              has_growth_stages: entry.has_growth_stages,
              requirement: entry.agrr_requirement
            }
          end

          Calculators::AgrrCropsConfigCalculator.build(
            entries: entries,
            logger: logger
          )
        end

        # @param snapshot [Dtos::PlanAllocationAdjustReadSnapshot]
        # @param random_hex [Proc] SecureRandom.hex(4) 相当
        def to_interaction_rules(snapshot:, random_hex:)
          crop_groups = {}
          snapshot.plan_crop_snapshots.each do |entry|
            crop_groups[entry.crop_id.to_s] = entry.groups
          end

          Calculators::AgrrInteractionRulesCalculator.build(
            crop_groups: crop_groups,
            random_hex: random_hex
          )
        end
      end
    end
  end
end
