# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module TaskScheduleGenerationContextMapper
        module_function

        # @param plan_row [Dtos::TaskScheduleGenerationReadSnapshots::PlanRowSnapshot]
        # @param field_cultivation_rows [Array<Dtos::TaskScheduleGenerationReadSnapshots::FieldCultivationRowSnapshot>]
        # @param crop_rows_by_id [Hash{Integer => Dtos::TaskScheduleGenerationReadSnapshots::CropRowSnapshot}]
        # @param template_rows_by_crop_id [Hash{Integer => Array}]
        # @param blueprint_rows_by_crop_id [Hash{Integer => Array}]
        # @param agrr_requirement_by_crop_id [Hash{Integer => Hash}]
        def assemble(
          plan_row:,
          field_cultivation_rows:,
          crop_rows_by_id:,
          template_rows_by_crop_id:,
          blueprint_rows_by_crop_id:,
          agrr_requirement_by_crop_id:
        )
          field_snapshots = field_cultivation_rows.filter_map do |fc_row|
            crop_id = fc_row.crop_id
            next nil if crop_id.nil?

            crop_row = crop_rows_by_id[crop_id]
            next nil unless crop_row

            crop_snapshot = crop_snapshot_from(
              crop_row: crop_row,
              template_rows: template_rows_by_crop_id[crop_id] || [],
              blueprint_rows: blueprint_rows_by_crop_id[crop_id] || [],
              agrr_requirement: agrr_requirement_by_crop_id[crop_id]
            )

            Dtos::FieldCultivationScheduleSnapshot.new(
              id: fc_row.id,
              start_date: fc_row.start_date,
              crop: crop_snapshot
            )
          end

          plan_snapshot = Dtos::TaskSchedulePlanSnapshot.new(
            id: plan_row.id,
            predicted_weather_data: plan_row.predicted_weather_data,
            calculated_planning_start_date: plan_row.calculated_planning_start_date,
            field_cultivations: field_snapshots
          )

          Dtos::TaskScheduleGenerationContext.new(plan: plan_snapshot)
        end

        def crop_snapshot_from(crop_row:, template_rows:, blueprint_rows:, agrr_requirement:)
          templates = template_rows.map do |row|
            Dtos::CropTaskTemplateSnapshot.new(agricultural_task: row.agricultural_task)
          end

          blueprints = blueprint_rows.map do |row|
            Dtos::CropTaskScheduleBlueprintSnapshot.new(
              id: row.id,
              task_type: row.task_type,
              gdd_trigger: row.gdd_trigger,
              gdd_tolerance: row.gdd_tolerance,
              description: row.description,
              stage_name: row.stage_name,
              stage_order: row.stage_order,
              priority: row.priority,
              source: row.source,
              weather_dependency: row.weather_dependency,
              time_per_sqm: row.time_per_sqm,
              amount: row.amount,
              amount_unit: row.amount_unit,
              agricultural_task: row.agricultural_task
            )
          end

          Dtos::CropScheduleSnapshot.new(
            id: crop_row.id,
            name: crop_row.name,
            crop_task_templates: templates,
            crop_task_schedule_blueprints: blueprints,
            agrr_requirement: agrr_requirement
          )
        end
      end
    end
  end
end
