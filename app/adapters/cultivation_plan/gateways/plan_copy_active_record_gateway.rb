# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanCopyActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanCopyGateway
        def find_plan(source_plan_id:)
          plan = ::CultivationPlan.find(source_plan_id)
          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_fields(source_plan_id:)
          ::CultivationPlanField.where(cultivation_plan_id: source_plan_id).map do |field|
            Domain::CultivationPlan::Dtos::PlanCopyFieldRow.new(
              id: field.id,
              name: field.name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost,
              description: field.description
            )
          end
        end

        def list_crops(source_plan_id:)
          ::CultivationPlanCrop.where(cultivation_plan_id: source_plan_id).map do |crop|
            Domain::CultivationPlan::Dtos::PlanCopyCropRow.new(
              id: crop.id,
              crop_id: crop.crop_id,
              name: crop.name,
              variety: crop.variety,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area
            )
          end
        end

        def list_field_cultivations(source_plan_id:)
          ::FieldCultivation.where(cultivation_plan_id: source_plan_id).map do |fc|
            Domain::CultivationPlan::Dtos::PlanCopyFieldCultivationRow.new(
              cultivation_plan_field_id: fc.cultivation_plan_field_id,
              cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
              area: fc.area,
              status: fc.status
            )
          end
        end

        def create_plan(attrs:)
          plan_attrs = {
            farm_id: attrs.farm_id,
            user_id: attrs.user_id,
            total_area: attrs.total_area,
            plan_type: attrs.plan_type,
            plan_year: attrs.plan_year,
            plan_name: attrs.plan_name,
            planning_start_date: attrs.planning_start_date,
            planning_end_date: attrs.planning_end_date,
            status: attrs.status
          }
          plan_attrs[:session_id] = attrs.session_id if attrs.session_id.present?

          plan = ::CultivationPlan.create!(plan_attrs)
          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(plan)
        end

        def create_field(plan_id:, name:, area:, daily_fixed_cost:, description: nil)
          field = ::CultivationPlanField.create!(
            cultivation_plan_id: plan_id,
            name: name,
            area: area,
            daily_fixed_cost: daily_fixed_cost,
            description: description
          )
          Domain::CultivationPlan::Dtos::PlanCopyFieldRow.new(
            id: field.id,
            name: field.name,
            area: field.area,
            daily_fixed_cost: field.daily_fixed_cost,
            description: field.description
          )
        end

        def create_crop(plan_id:, crop_id:, name:, variety:, area_per_unit:, revenue_per_area:)
          crop = ::CultivationPlanCrop.create!(
            cultivation_plan_id: plan_id,
            crop_id: crop_id,
            name: name,
            variety: variety,
            area_per_unit: area_per_unit,
            revenue_per_area: revenue_per_area
          )
          Domain::CultivationPlan::Dtos::PlanCopyCropRow.new(
            id: crop.id,
            crop_id: crop.crop_id,
            name: crop.name,
            variety: crop.variety,
            area_per_unit: crop.area_per_unit,
            revenue_per_area: crop.revenue_per_area
          )
        end

        def create_field_cultivation(plan_id:, cultivation_plan_field_id:, cultivation_plan_crop_id:, area:, status:)
          ::FieldCultivation.create!(
            cultivation_plan_id: plan_id,
            cultivation_plan_field_id: cultivation_plan_field_id,
            cultivation_plan_crop_id: cultivation_plan_crop_id,
            area: area,
            status: status
          )
        end

        def copy_attachments(source_plan_id:, target_plan_id:)
          source_plan = ::CultivationPlan.find(source_plan_id)
          new_plan = ::CultivationPlan.find(target_plan_id)
          self.class.copy_attachments_for_plan_copy(source_plan: source_plan, new_plan: new_plan)
        end

        def self.copy_attachments_for_plan_copy(source_plan:, new_plan:)
          attachments = ::ActiveStorage::Attachment.where(record: source_plan)
          attachments_count = attachments.count

          attachments.find_each do |attachment|
            ::ActiveStorage::Attachment.create!(
              name: attachment.name,
              record: new_plan,
              blob: attachment.blob
            )
          end

          attachments_count
        end

        def self.cultivation_period_pairs_from_plan(reference_plan)
          reference_plan.field_cultivations.where.not(start_date: nil, completion_date: nil).map do |fc|
            { start_date: fc.start_date, completion_date: fc.completion_date }
          end
        end

        def initialize(ctx: nil, logger: nil, clock: nil)
          @ctx = ctx
          @logger = logger
          @clock = clock
          return unless ctx

          @task_mapper = Adapters::CultivationPlan::Mappers::AgriculturalTaskMapper.new(ctx)
          @calc = Domain::CultivationPlan::Calculators::PlanningDateCalculator
        end

        def copy_cultivation_plan(farm, _crops)
          plan_id = @ctx.session_data[:plan_id] || @ctx.session_data["plan_id"]
          @logger.debug I18n.t("services.plan_save_service.debug.plan_id_extracted", plan_id: plan_id)

          reference_plan = ::CultivationPlan.includes(:field_cultivations).find(plan_id)
          @logger.debug I18n.t("services.plan_save_service.debug.reference_plan_found", plan_name: reference_plan.plan_name)

          cultivation_periods = self.class.cultivation_period_pairs_from_plan(reference_plan)

          if reference_plan.plan_year.nil?
            planning_dates = @calc.calculate_planning_dates_from_cultivations(
              cultivation_periods: cultivation_periods,
              logger: @logger,
              as_of: @clock.today
            )
            plan_year = nil
            @logger.info "📅 [PlanSaveService] Reference plan is annual planning (plan_year is null), calculated dates from cultivations"
          else
            plan_year = @calc.calculate_plan_year_from_cultivations(
              cultivation_periods: cultivation_periods,
              logger: @logger,
              as_of: @clock.today
            )
            planning_dates = ::CultivationPlan.calculate_planning_dates(plan_year)
            @logger.info "📅 [PlanSaveService] Calculated plan_year: #{plan_year} from field_cultivations"
          end

          new_plan = ::CultivationPlan.create!(
            farm: farm,
            user: @ctx.user,
            total_area: reference_plan.total_area,
            plan_type: "private",
            plan_year: plan_year,
            plan_name: "#{reference_plan.farm.name}の計画",
            planning_start_date: planning_dates[:start_date],
            planning_end_date: planning_dates[:end_date],
            status: "pending",
            predicted_weather_data: reference_plan.predicted_weather_data
          )

          if reference_plan.predicted_weather_data.present?
            @logger.info "✅ [PlanSaveService] Copied predicted_weather_data to new plan ##{new_plan.id}"
          else
            @logger.warn "⚠️ [PlanSaveService] Reference plan has no predicted_weather_data"
          end

          @logger.info I18n.t("services.plan_save_service.messages.plan_created", plan_id: new_plan.id)
          new_plan
        rescue ActiveRecord::RecordNotFound => e
          @logger.error I18n.t("services.plan_save_service.errors.plan_not_found", plan_id: plan_id)
          raise e
        rescue ActiveRecord::RecordInvalid => e
          @logger.error I18n.t("services.plan_save_service.errors.plan_creation_failed", errors: e.message)
          raise e
        end

        def establish_master_data_relationships(farm, crops, fields, pests, agricultural_tasks, fertilizes, pesticides, interaction_rules)
          @logger.info "🔍 [PlanSaveService] Data integrity check:"
          @logger.info "  - Farm: #{farm.name} (ID: #{farm.id})"
          @logger.info "  - Fields: #{fields.count} fields"
          @logger.info "  - Crops: #{crops.count} crops"
          @logger.info "  - Pests: #{pests.count} pests"
          @logger.info "  - Agricultural tasks: #{agricultural_tasks.count} tasks"
          @logger.info "  - Fertilizes: #{fertilizes.count} fertilizes"
          @logger.info "  - Pesticides: #{pesticides.count} pesticides"
          @logger.info "  - Interaction rules: #{interaction_rules.count} rules"

          if farm.fields.count != fields.count
            @logger.warn "⚠️ [PlanSaveService] Field count mismatch: farm.fields.count=#{farm.fields.count}, fields.count=#{fields.count}"
          end

          raise "Some fields were not properly created" unless fields.all?(&:persisted?)
          raise "Some crops were not properly created" unless crops.all?(&:persisted?)
          raise "Some pests were not properly created" unless pests.all?(&:persisted?)
          raise "Some agricultural tasks were not properly created" unless agricultural_tasks.all?(&:persisted?)
          raise "Some fertilizes were not properly created" unless fertilizes.all?(&:persisted?)
          raise "Some pesticides were not properly created" unless pesticides.all?(&:persisted?)
          raise "Some interaction rules were not properly created" unless interaction_rules.all?(&:persisted?)

          @logger.info "✅ [PlanSaveService] All master data relationships established successfully"
        end

        def copy_plan_relations(new_plan)
          plan_id = @ctx.session_data[:plan_id] || @ctx.session_data["plan_id"]
          reference_plan = ::CultivationPlan.includes(
            :cultivation_plan_fields,
            :cultivation_plan_crops,
            :field_cultivations,
            cultivation_plan_crops: :crop,
            field_cultivations: [ :cultivation_plan_field, :cultivation_plan_crop ]
          ).find(plan_id)

          new_fields = reference_plan.cultivation_plan_fields.map do |reference_field|
            ::CultivationPlanField.create!(
              cultivation_plan: new_plan,
              name: reference_field.name,
              area: reference_field.area,
              daily_fixed_cost: reference_field.daily_fixed_cost,
              description: reference_field.description
            )
          end

          new_crops = []
          reference_plan.cultivation_plan_crops.order(:id).each do |reference_crop_plan|
            user_crop_id = @ctx.ref_cpc_id_to_user_crop_id[reference_crop_plan.id]
            next unless user_crop_id

            new_crop = ::CultivationPlanCrop.create!(
              cultivation_plan: new_plan,
              crop_id: user_crop_id,
              name: reference_crop_plan.name,
              variety: reference_crop_plan.variety,
              area_per_unit: reference_crop_plan.area_per_unit,
              revenue_per_area: reference_crop_plan.revenue_per_area
            )
            new_crops << new_crop

            @logger.debug "✅ [PlanSaveService] Created CultivationPlanCrop: #{new_crop.name} (variety: #{new_crop.variety})"
          end

          field_cultivation_count = 0
          field_cultivation_map = {}
          reference_plan.field_cultivations.each do |reference_field_cultivation|
            new_field = new_fields.find { |f| f.name == reference_field_cultivation.cultivation_plan_field.name }

            mapped_user_crop_id = @ctx.ref_cpc_id_to_user_crop_id[reference_field_cultivation.cultivation_plan_crop_id]
            new_crop = new_crops.find { |c| c.crop_id == mapped_user_crop_id }

            unless new_field && new_crop
              @logger.warn "⚠️ [PlanSaveService] Skipping FieldCultivation: field=#{new_field&.name}, crop=#{new_crop&.name}"
              next
            end

            new_field_cultivation = ::FieldCultivation.create!(
              cultivation_plan: new_plan,
              cultivation_plan_field: new_field,
              cultivation_plan_crop: new_crop,
              area: reference_field_cultivation.area,
              start_date: reference_field_cultivation.start_date,
              completion_date: reference_field_cultivation.completion_date,
              cultivation_days: reference_field_cultivation.cultivation_days,
              estimated_cost: reference_field_cultivation.estimated_cost,
              status: reference_field_cultivation.status,
              optimization_result: reference_field_cultivation.optimization_result
            )
            field_cultivation_count += 1
            field_cultivation_map[reference_field_cultivation.id] = new_field_cultivation.id

            @logger.debug "✅ [PlanSaveService] Created FieldCultivation: #{new_field.name} + #{new_crop.name}"
          end

          @logger.info I18n.t("services.plan_save_service.debug.plan_relations_copied",
                                  fields: new_fields.count,
                                  crops: new_crops.count,
                                  cultivations: field_cultivation_count)
          field_cultivation_map
        rescue => e
          @logger.error I18n.t("services.plan_save_service.errors.plan_relations_copy_failed", errors: e.message)
          raise e
        end

        def copy_task_schedules(new_plan, field_cultivation_map)
          plan_id = @ctx.session_data[:plan_id] || @ctx.session_data["plan_id"]
          reference_plan = ::CultivationPlan.includes(task_schedules: { task_schedule_items: :agricultural_task }).find(plan_id)

          invalid_item = ::TaskScheduleItem
                           .joins(:task_schedule)
                           .find_by(task_schedules: { cultivation_plan_id: plan_id }, gdd_trigger: nil)
          if invalid_item
            raise Adapters::CultivationPlan::Sessions::PlanSaveSession::InvalidTaskScheduleItemError,
                  "Reference TaskScheduleItem##{invalid_item.id} has nil gdd_trigger"
          end

          return if field_cultivation_map.blank?

          reference_plan.task_schedules.each do |reference_schedule|
            new_field_cultivation_id = field_cultivation_map[reference_schedule.field_cultivation_id]
            next unless new_field_cultivation_id

            new_schedule = ::TaskSchedule.create!(
              cultivation_plan: new_plan,
              field_cultivation_id: new_field_cultivation_id,
              category: reference_schedule.category,
              status: reference_schedule.status || "active",
              source: "copied_from_public_plan",
              generated_at: reference_schedule.generated_at
            )

            reference_schedule.task_schedule_items.each do |reference_item|
              mapped_task_id = @task_mapper.mapped_agricultural_task_id(reference_item)

              if reference_item.gdd_trigger.nil?
                raise Adapters::CultivationPlan::Sessions::PlanSaveSession::InvalidTaskScheduleItemError,
                      "Reference TaskScheduleItem##{reference_item.id} has nil gdd_trigger"
              end

              ::TaskScheduleItem.create!(
                task_schedule: new_schedule,
                task_type: reference_item.task_type,
                name: reference_item.name,
                stage_name: reference_item.stage_name,
                stage_order: reference_item.stage_order,
                gdd_trigger: reference_item.gdd_trigger,
                gdd_tolerance: reference_item.gdd_tolerance,
                scheduled_date: reference_item.scheduled_date,
                priority: reference_item.priority,
                source: reference_item.source,
                weather_dependency: reference_item.weather_dependency,
                time_per_sqm: reference_item.time_per_sqm,
                amount: reference_item.amount,
                amount_unit: reference_item.amount_unit,
                status: reference_item.status.presence || ::TaskScheduleItem::STATUSES[:planned],
                actual_date: reference_item.actual_date,
                actual_notes: reference_item.actual_notes,
                rescheduled_at: reference_item.rescheduled_at,
                cancelled_at: reference_item.cancelled_at,
                completed_at: reference_item.completed_at,
                agricultural_task_id: mapped_task_id,
                source_agricultural_task_id: reference_item.source_agricultural_task_id || reference_item.agricultural_task&.id
              )
            end
          end
        rescue => e
          @logger.error "❌ [PlanSaveService] Task schedule copy failed: #{e.message}"
          raise e
        end
      end
    end
  end
end
