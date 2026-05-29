# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class TaskScheduleGenerationContextMapperTest < DomainLibTestCase
        ReadSnapshots = Dtos::TaskScheduleGenerationReadSnapshots
        PlanRowSnapshot = ReadSnapshots::PlanRowSnapshot
        FieldCultivationRowSnapshot = ReadSnapshots::FieldCultivationRowSnapshot
        CropRowSnapshot = ReadSnapshots::CropRowSnapshot
        TemplateRowSnapshot = ReadSnapshots::CropTaskTemplateRowSnapshot
        BlueprintRowSnapshot = ReadSnapshots::BlueprintRowSnapshot

        test "assemble builds context with field cultivations and crop snapshots" do
          plan_row = PlanRowSnapshot.new(
            id: 10,
            predicted_weather_data: { "data" => [] },
            calculated_planning_start_date: Date.new(2025, 1, 1)
          )
          field_rows = [
            FieldCultivationRowSnapshot.new(id: 7, start_date: Date.new(2025, 4, 1), crop_id: 1)
          ]
          crop_rows_by_id = { 1 => CropRowSnapshot.new(id: 1, name: "トマト") }
          template_rows_by_crop_id = { 1 => [ TemplateRowSnapshot.new(agricultural_task: nil) ] }
          blueprint_rows_by_crop_id = {
            1 => [
              BlueprintRowSnapshot.new(
                id: 1,
                task_type: "field_work",
                gdd_trigger: BigDecimal("0"),
                gdd_tolerance: nil,
                description: nil,
                stage_name: "土壌",
                stage_order: 1,
                priority: 1,
                source: "agrr",
                weather_dependency: nil,
                time_per_sqm: nil,
                amount: nil,
                amount_unit: nil,
                agricultural_task: nil
              )
            ]
          }
          agrr_requirement_by_crop_id = { 1 => { "crop" => { "name" => "トマト" } } }

          ctx = TaskScheduleGenerationContextMapper.assemble(
            plan_row: plan_row,
            field_cultivation_rows: field_rows,
            crop_rows_by_id: crop_rows_by_id,
            template_rows_by_crop_id: template_rows_by_crop_id,
            blueprint_rows_by_crop_id: blueprint_rows_by_crop_id,
            agrr_requirement_by_crop_id: agrr_requirement_by_crop_id
          )

          assert_equal 10, ctx.plan.id
          assert_equal 1, ctx.plan.field_cultivations.size
          assert_equal 7, ctx.plan.field_cultivations.first.id
          assert_equal "トマト", ctx.plan.field_cultivations.first.crop.name
          assert_equal 1, ctx.plan.field_cultivations.first.crop.crop_task_schedule_blueprints.size
        end
      end
    end
  end
end
