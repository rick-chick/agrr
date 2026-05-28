# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanPrivateReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanPrivateReadGateway
        def find_plan_read_snapshot_by_plan_id(plan_id:)
          Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure do
            plan = ::CultivationPlan
                     .includes(
                       :farm,
                       field_cultivations: [ :cultivation_plan_field, :cultivation_plan_crop ],
                       cultivation_plan_fields: [],
                       cultivation_plan_crops: [ :crop ]
                     )
                     .find(plan_id)

            field_cultivations = plan.field_cultivations.map do |fc|
              Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail::FieldCultivationRead.new(
                id: fc.id,
                cultivation_plan_field_id: fc.cultivation_plan_field_id,
                field_display_name: fc.field_display_name,
                cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
                crop_display_name: fc.crop_display_name,
                start_date: fc.start_date,
                completion_date: fc.completion_date,
                cultivation_days: fc.cultivation_days,
                area: fc.area,
                estimated_cost: fc.estimated_cost,
                optimization_profit: Domain::CultivationPlan::GanttChartRowHashes.profit_from_optimization_result(
                  fc.optimization_result
                )
              )
            end

            cultivation_plan_fields = plan.cultivation_plan_fields.map do |field|
              Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail::PlanFieldRead.new(
                id: field.id,
                name: field.name,
                area: field.area
              )
            end

            palette_used_crop_ids = plan.cultivation_plan_crops.map { |cpc| cpc.crop&.id }.compact

            Domain::CultivationPlan::Dtos::PrivatePlanReadSnapshot.new(
              id: plan.id,
              display_name: plan.display_name,
              farm_display_name: plan.farm.display_name,
              total_area: plan.total_area,
              field_cultivations_count: plan.field_cultivations.size,
              cultivation_plan_fields_count: plan.cultivation_plan_fields.size,
              planning_start_date: plan.planning_start_date,
              planning_end_date: plan.planning_end_date,
              status: plan.status,
              field_cultivations: field_cultivations,
              cultivation_plan_fields: cultivation_plan_fields,
              palette_used_crop_ids: palette_used_crop_ids
            )
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_task_schedule_timeline_by_plan_id(plan_id:)
          plan = ::CultivationPlan.find(plan_id)
          schedules = TaskSchedule.where(cultivation_plan_id: plan.id)
                                  .includes(
                                    { task_schedule_items: :agricultural_task },
                                    field_cultivation: [
                                      :cultivation_plan_field,
                                      {
                                        cultivation_plan_crop: {
                                          crop: [
                                            :agricultural_tasks,
                                            { crop_task_templates: :agricultural_task }
                                          ]
                                        }
                                      }
                                    ]
                                  )

          timeline_generated_at = schedules.maximum(:generated_at)
          scheduled_dates = TaskScheduleItem
                              .joins(:task_schedule)
                              .where(task_schedules: { cultivation_plan_id: plan.id })
                              .where.not(scheduled_date: nil)
                              .pluck(:scheduled_date)

          fields = schedules.group_by(&:field_cultivation).map do |field_cultivation, field_schedules|
            build_task_schedule_timeline_field(field_cultivation, field_schedules)
          end

          Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot.new(
            plan: Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot::PlanRead.new(
              id: plan.id,
              display_name: plan.display_name,
              status: plan.status,
              planning_start_date: plan.planning_start_date,
              planning_end_date: plan.planning_end_date,
              timeline_generated_at: timeline_generated_at,
              farm_display_name: plan.farm.display_name,
              total_area: plan.total_area
            ),
            fields: fields,
            scheduled_dates: scheduled_dates
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_private_plan_index_rows_by_user_id(user_id:)
          Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure do
            plans = ::CultivationPlan
                      .plan_type_private
                      .where(user_id: user_id)
                      .select(
                        :id, :status, :plan_year, :plan_name, :plan_type,
                        :total_area, :farm_id, :planning_start_date, :planning_end_date,
                        :created_at, :updated_at
                      )
                      .preload(:farm)
                      .recent
                      .to_a

            plan_ids = plans.map(&:id)
            crops_count_hash = if plan_ids.empty?
              {}
            else
              ::CultivationPlanCrop.where(cultivation_plan_id: plan_ids)
                                   .group(:cultivation_plan_id)
                                   .count
            end
            fields_count_hash = if plan_ids.empty?
              {}
            else
              ::CultivationPlanField.where(cultivation_plan_id: plan_ids)
                                    .group(:cultivation_plan_id)
                                    .count
            end

            ordered_plans = plans.group_by(&:farm_id).values.flatten
            ordered_plans.map do |p|
              Domain::CultivationPlan::Dtos::PrivatePlanIndexPlanRow.new(
                id: p.id,
                farm_display_name: p.farm.display_name,
                total_area: p.total_area,
                crops_count: crops_count_hash[p.id] || 0,
                fields_count: fields_count_hash[p.id] || 0,
                status: p.status,
                display_name: p.display_name,
                created_at: p.created_at
              )
            end
          end
        end

        def find_optimization_snapshot_by_plan_id(plan_id:)
          plan = ::CultivationPlan.find(plan_id)
          Mappers::OptimizationPlanReadSnapshotMapper.from_cultivation_plan(plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        private

        def build_task_schedule_timeline_field(field_cultivation, schedules)
          task_options = build_task_schedule_task_options(field_cultivation)
          schedule_reads = schedules.map { |schedule| build_task_schedule_timeline_schedule(schedule) }

          Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot::FieldRead.new(
            id: field_cultivation&.id,
            name: field_cultivation&.cultivation_plan_field&.name,
            crop_name: field_cultivation&.cultivation_plan_crop&.name || field_cultivation&.cultivation_plan_crop&.crop&.name,
            area_sqm: field_cultivation&.area,
            field_cultivation_id: field_cultivation&.id,
            crop_id: field_cultivation&.cultivation_plan_crop_id,
            task_options: task_options,
            schedules: schedule_reads
          )
        end

        def build_task_schedule_timeline_schedule(schedule)
          items = schedule.task_schedule_items.map do |item|
            Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot::ItemRead.new(
              id: item.id,
              name: item.name,
              task_type: item.task_type,
              scheduled_date: item.scheduled_date,
              stage_name: item.stage_name,
              stage_order: item.stage_order,
              gdd_trigger: item.gdd_trigger,
              gdd_tolerance: item.gdd_tolerance,
              priority: item.priority,
              source: item.source,
              weather_dependency: item.weather_dependency,
              time_per_sqm: item.time_per_sqm,
              amount: item.amount,
              amount_unit: item.amount_unit,
              status: item.respond_to?(:status) ? item.status : nil,
              agricultural_task_id: item.agricultural_task_id,
              field_cultivation_id: schedule.field_cultivation_id,
              agricultural_task: build_task_schedule_task_master(item.agricultural_task),
              actual_date: item.actual_date,
              actual_notes: item.actual_notes,
              rescheduled_at: item.rescheduled_at,
              cancelled_at: item.cancelled_at,
              completed_at: item.completed_at
            )
          end

          Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot::ScheduleRead.new(
            category: schedule.category,
            items: items
          )
        end

        def build_task_schedule_task_master(task)
          return nil unless task

          Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot::AgriculturalTaskRead.new(
            name: task.name,
            description: task.description,
            time_per_sqm: task.time_per_sqm,
            weather_dependency: task.weather_dependency,
            required_tools: Array(task.required_tools).presence,
            skill_level: task.skill_level,
            task_type: task.task_type
          )
        end

        def build_task_schedule_task_options(field_cultivation)
          crop = field_cultivation&.cultivation_plan_crop&.crop
          return [] unless crop

          crop.crop_task_templates.sort_by(&:name).map do |template|
            Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot::TaskOptionRead.new(
              template_id: template.id,
              name: template.name,
              task_type: template.task_type || TaskScheduleItem::FIELD_WORK_TYPE,
              agricultural_task_id: template.agricultural_task_id,
              description: template.description,
              weather_dependency: template.weather_dependency,
              time_per_sqm: template.time_per_sqm,
              required_tools: Array(template.required_tools).presence,
              skill_level: template.skill_level
            )
          end
        end
      end
    end
  end
end
