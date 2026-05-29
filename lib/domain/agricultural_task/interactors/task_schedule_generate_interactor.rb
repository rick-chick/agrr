# frozen_string_literal: true

# 作業予定（TaskSchedule）生成。旧 TaskScheduleGeneratorService（T-033）。
module Domain
  module AgriculturalTask
    module Interactors
      class TaskScheduleGenerateInteractor
        class Error < StandardError; end
        class WeatherDataMissingError < Error; end
        class ProgressDataMissingError < Error; end
        class GddTriggerMissingError < Error; end
        class TemplateMissingError < Error; end

        def initialize(
          progress_gateway:,
          task_schedule_gateway:,
          clock:,
          cultivation_plan_gateway:,
          task_schedule_read_gateway:,
          crop_agrr_requirement_builder:
        )
          @progress_gateway = progress_gateway
          @task_schedule_gateway = task_schedule_gateway
          @clock = clock
          @cultivation_plan_gateway = cultivation_plan_gateway
          @task_schedule_read_gateway = task_schedule_read_gateway
          @crop_agrr_requirement_builder = crop_agrr_requirement_builder
        end

        def generate!(cultivation_plan_id:)
          ctx = build_generation_context(cultivation_plan_id)
          plan = ctx.plan

          unless plan.predicted_weather_data.present?
            raise WeatherDataMissingError, "CultivationPlan##{plan.id} に気象予測データが存在しません"
          end

          blueprint_cache = {}

          @cultivation_plan_gateway.within_transaction do
            plan.field_cultivations.each do |field_cultivation|
              generate_for_field(plan, field_cultivation, blueprint_cache)
            end
          end
        end

        private

        attr_reader :progress_gateway,
                    :task_schedule_gateway,
                    :clock,
                    :cultivation_plan_gateway,
                    :task_schedule_read_gateway,
                    :crop_agrr_requirement_builder

        def build_generation_context(cultivation_plan_id)
          plan_row = @task_schedule_read_gateway.find_plan_row(plan_id: cultivation_plan_id)
          field_rows = @task_schedule_read_gateway.list_field_cultivation_rows(plan_id: cultivation_plan_id)

          crop_ids = field_rows.map(&:crop_id).compact.uniq
          crop_rows_by_id = crop_ids.each_with_object({}) do |crop_id, hash|
            hash[crop_id] = @task_schedule_read_gateway.find_crop_row(crop_id: crop_id)
          end
          template_rows_by_crop_id = crop_ids.each_with_object({}) do |crop_id, hash|
            hash[crop_id] = @task_schedule_read_gateway.list_crop_task_template_rows(crop_id: crop_id)
          end
          blueprint_rows_by_crop_id = crop_ids.each_with_object({}) do |crop_id, hash|
            hash[crop_id] = @task_schedule_read_gateway.list_crop_task_schedule_blueprint_rows(crop_id: crop_id)
          end
          agrr_requirement_by_crop_id = crop_ids.each_with_object({}) do |crop_id, hash|
            source = @task_schedule_read_gateway.find_crop_agrr_requirement_source(crop_id: crop_id)
            hash[crop_id] = @crop_agrr_requirement_builder.build_from(source)
          end

          Domain::CultivationPlan::Mappers::TaskScheduleGenerationContextMapper.assemble(
            plan_row: plan_row,
            field_cultivation_rows: field_rows,
            crop_rows_by_id: crop_rows_by_id,
            template_rows_by_crop_id: template_rows_by_crop_id,
            blueprint_rows_by_crop_id: blueprint_rows_by_crop_id,
            agrr_requirement_by_crop_id: agrr_requirement_by_crop_id
          )
        end

        def generate_for_field(plan, field_cultivation, blueprint_cache)
          crop = field_cultivation.crop
          return unless crop

          blueprints = blueprints_for(crop, blueprint_cache)
          if blueprints.empty?
            raise TemplateMissingError, "Crop##{crop.id} (#{crop.name}) の作業テンプレートが登録されていません"
          end

          general_blueprints, fertilizer_blueprints = partition_blueprints(blueprints)
          if general_blueprints.empty?
            raise TemplateMissingError, "Crop##{crop.id} (#{crop.name}) の一般作業テンプレートが不足しています"
          end

          agricultural_tasks_lookup = index_agricultural_tasks(crop)

          start_date = field_cultivation.start_date || plan.calculated_planning_start_date
          filtered_weather = filtered_weather_data(plan.predicted_weather_data, start_date)
          progress_data = progress_for_crop(crop, start_date, filtered_weather)

          progress_records = Array(progress_data["progress_records"])
          filtered_records = if start_date.present?
            progress_records.select do |record|
              record_date = safe_parse_date(record["date"])
              record_date && record_date >= start_date
            end
          else
            []
          end
          progress_records = filtered_records if filtered_records.present?
          if progress_records.empty?
            raise ProgressDataMissingError, "GDD進捗データが空です (cultivation_plan_id=#{plan.id})"
          end

          create_schedule!(
            plan: plan,
            field_cultivation: field_cultivation,
            category: "general"
          ) do
            general_blueprints.map do |blueprint|
              item_attributes_for_blueprint(
                blueprint: blueprint,
                agricultural_tasks_lookup: agricultural_tasks_lookup,
                progress_records: progress_records,
                fallback_start_date: field_cultivation.start_date
              )
            end
          end

          if fertilizer_blueprints.any?
            create_schedule!(
              plan: plan,
              field_cultivation: field_cultivation,
              category: "fertilizer"
            ) do
              fertilizer_blueprints.map do |blueprint|
                item_attributes_for_blueprint(
                  blueprint: blueprint,
                  agricultural_tasks_lookup: agricultural_tasks_lookup,
                  progress_records: progress_records,
                  fallback_start_date: field_cultivation.start_date
                )
              end
            end
          else
            clear_schedule(plan: plan, field_cultivation: field_cultivation, category: "fertilizer")
          end
        end

        def progress_for_crop(crop, start_date, weather_data)
          progress_gateway.calculate_progress(
            crop_requirement: crop.to_agrr_requirement,
            start_date: start_date,
            weather_data: weather_data,
            crop: crop
          )
        end

        def index_agricultural_tasks(crop)
          lookup = {}
          crop.crop_task_templates.each do |template|
            task = template.agricultural_task
            if task
              lookup[task.id] = task
              lookup[task.id.to_s] = task
            end
          end
          lookup
        end

        def blueprints_for(crop, cache)
          return cache[crop.id] if cache.key?(crop.id)

          cache[crop.id] = crop.crop_task_schedule_blueprints
        end

        def partition_blueprints(blueprints)
          general = []
          fertilizer = []

          types = Domain::AgriculturalTask::Constants::ScheduleItemTypes
          blueprints.each do |blueprint|
            case blueprint.task_type
            when types::FIELD_WORK
              general << blueprint
            when types::BASAL_FERTILIZATION, types::TOPDRESS_FERTILIZATION
              fertilizer << blueprint
            end
          end

          [ general, fertilizer ]
        end

        def item_attributes_for_blueprint(blueprint:, agricultural_tasks_lookup:, progress_records:, fallback_start_date:)
          gdd_trigger = blueprint.gdd_trigger
          if gdd_trigger.nil?
            raise GddTriggerMissingError, "GDDトリガーが設定されていません"
          end

          task = find_agricultural_task_for_blueprint(blueprint, agricultural_tasks_lookup)

          {
            task_type: blueprint.task_type,
            agricultural_task_id: task&.id,
            name: name_for_blueprint(blueprint, task),
            description: (blueprint.description if blueprint.description.present?) || task&.description,
            stage_name: blueprint.stage_name,
            stage_order: blueprint.stage_order,
            gdd_trigger: gdd_trigger,
            gdd_tolerance: blueprint.gdd_tolerance,
            scheduled_date: date_for_gdd(progress_records, gdd_trigger, fallback_start_date),
            priority: blueprint.priority,
            source: blueprint.source,
            status: Domain::AgriculturalTask::Constants::TaskScheduleItemStatuses::PLANNED,
            weather_dependency: blueprint.weather_dependency || task&.weather_dependency,
            time_per_sqm: blueprint.time_per_sqm || task&.time_per_sqm,
            amount: blueprint.amount,
            amount_unit: blueprint.amount_unit || (blueprint.amount.present? ? "g/m2" : nil)
          }
        end

        def find_agricultural_task_for_blueprint(blueprint, lookup)
          blueprint.agricultural_task
        end

        def name_for_blueprint(blueprint, task)
          # 関連作業が設定されている場合は、その名前を優先
          return task.name if task && task.name.present?
          # 関連作業が未設定の場合、agrrが返した作業名（description）を優先的に使用
          # agrrが返したnameを優先し、stage_nameは使用しない
          return blueprint.description if blueprint.description.present?

          types = Domain::AgriculturalTask::Constants::ScheduleItemTypes
          case blueprint.task_type
          when types::BASAL_FERTILIZATION
            "基肥施用"
          when types::TOPDRESS_FERTILIZATION
            "追肥施用"
          else
            "field_task"
          end
        end

        def clear_schedule(plan:, field_cultivation:, category:)
          task_schedule_gateway.delete_all_for_field_category(
            cultivation_plan_id: plan.id,
            field_cultivation_id: field_cultivation.id,
            category: category
          )
        end

        def create_schedule!(plan:, field_cultivation:, category:)
          items = yield
          task_schedule_gateway.replace_schedule_for_field_category!(
            cultivation_plan_id: plan.id,
            field_cultivation_id: field_cultivation.id,
            category: category,
            generated_at: clock.now,
            items: items
          )
        end

        def date_for_gdd(progress_records, target_gdd, fallback_date)
          target_value = decimal_value(target_gdd)
          if target_value.nil?
            raise GddTriggerMissingError, "GDDトリガーが設定されていません"
          end

          progress_records.each do |record|
            cumulative = decimal_value(record["cumulative_gdd"])
            next if target_value.present? && cumulative < target_value

            return Date.parse(record["date"])
          end

          raise ProgressDataMissingError, "GDD #{target_value} に対応する日付が見つかりません"
        rescue ArgumentError
          fallback_date
        end

        def decimal_value(value)
          Domain::Shared::TypeConverters::BigDecimalConverter.cast(value)
        end

        def safe_parse_date(value)
          return value if value.is_a?(Date)

          Date.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def filtered_weather_data(weather_data, start_date)
          return weather_data unless start_date && weather_data.is_a?(Hash)

          duplicated = Domain::Shared.deep_dup(weather_data)
          data_array = Array(duplicated["data"] || duplicated[:data])

          filtered = data_array.select do |entry|
            entry_time = entry["time"] || entry[:time]
            entry_time.present? && safe_parse_date(entry_time) && safe_parse_date(entry_time) >= start_date
          end

          if filtered.any?
            if duplicated.key?("data")
              duplicated["data"] = filtered
            else
              duplicated[:data] = filtered
            end
          end

          duplicated
        end
      end
    end
  end
end
