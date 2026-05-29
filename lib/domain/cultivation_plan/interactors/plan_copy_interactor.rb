# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 年度指定で既存計画を私有コピーする（永続化は PlanCopyGateway 経由）。
      class PlanCopyInteractor
        def initialize(plan_copy_gateway:, logger:)
          @plan_copy_gateway = plan_copy_gateway
          @logger = logger
        end

        # @param input [Domain::CultivationPlan::Dtos::PlanCopyInput]
        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def call(input)
          source_plan = @plan_copy_gateway.find_plan(source_plan_id: input.source_cultivation_plan_id)
          planning_dates = Calculators::PlanningDateCalculator.calculate_planning_dates(input.new_year)

          create_attrs = Dtos::PlanCopyCreateAttrs.new(
            farm_id: source_plan.farm_id,
            user_id: input.user_id,
            total_area: source_plan.total_area,
            plan_type: "private",
            plan_year: input.new_year,
            plan_name: source_plan.plan_name,
            planning_start_date: planning_dates[:start_date],
            planning_end_date: planning_dates[:end_date],
            status: "pending",
            session_id: input.session_id
          )

          new_plan = @plan_copy_gateway.create_plan(attrs: create_attrs)
          @logger.info "✅ Created new plan ##{new_plan.id} (year: #{input.new_year})"

          source_fields = @plan_copy_gateway.list_fields(source_plan_id: input.source_cultivation_plan_id)
          new_fields = source_fields.map do |source_field|
            @plan_copy_gateway.create_field(
              plan_id: new_plan.id,
              name: source_field.name,
              area: source_field.area,
              daily_fixed_cost: source_field.daily_fixed_cost,
              description: source_field.description
            )
          end
          @logger.info "✅ Copied #{source_fields.size} fields"

          source_crops = @plan_copy_gateway.list_crops(source_plan_id: input.source_cultivation_plan_id)
          new_crops = source_crops.map do |source_crop|
            @plan_copy_gateway.create_crop(
              plan_id: new_plan.id,
              crop_id: source_crop.crop_id,
              name: source_crop.name,
              variety: source_crop.variety,
              area_per_unit: source_crop.area_per_unit,
              revenue_per_area: source_crop.revenue_per_area
            )
          end
          @logger.info "✅ Copied #{source_crops.size} crops"

          field_mapping = {}
          source_fields.each_with_index do |source_field, index|
            field_mapping[source_field.id] = new_fields[index].id
          end

          crop_mapping = {}
          source_crops.each_with_index do |source_crop, index|
            crop_mapping[source_crop.id] = new_crops[index].id
          end

          source_field_cultivations = @plan_copy_gateway.list_field_cultivations(
            source_plan_id: input.source_cultivation_plan_id
          )
          source_field_cultivations.each do |source_fc|
            @plan_copy_gateway.create_field_cultivation(
              plan_id: new_plan.id,
              cultivation_plan_field_id: field_mapping[source_fc.cultivation_plan_field_id],
              cultivation_plan_crop_id: crop_mapping[source_fc.cultivation_plan_crop_id],
              area: source_fc.area,
              status: source_fc.status
            )
          end

          @logger.info "✅ Copied #{source_field_cultivations.size} field cultivations"
          @logger.info "✅ Plan copy completed: #{input.source_cultivation_plan_id} -> #{new_plan.id}"

          @plan_copy_gateway.find_plan(source_plan_id: new_plan.id)
        end
      end
    end
  end
end
