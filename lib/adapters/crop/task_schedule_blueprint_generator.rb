# frozen_string_literal: true

module Adapters
  module Crop
    # agrr API 応答から CropTaskScheduleBlueprint 作成用属性の配列を組み立てる（永続化境界で AR を参照）。
    class TaskScheduleBlueprintGenerator
      def initialize(crop:, templates: nil)
        @crop = crop
        @templates = Array(templates).presence || crop.crop_task_templates.includes(:agricultural_task).to_a
      end

      def build_from_responses(schedule_response:, fertilize_response:)
        blueprint_attributes = []

        blueprint_attributes.concat(
          Array(schedule_response&.dig("task_schedules")).map do |task|
            build_general_blueprint(task)
          end.compact
        )

        blueprint_attributes.concat(
          Array(fertilize_response&.dig("schedule")).each_with_index.map do |entry, index|
            build_fertilizer_blueprint(entry, index)
          end.compact
        )

        blueprint_attributes
      end

      private

      attr_reader :crop, :templates

      def build_general_blueprint(task)
        task_id = Domain::Crop::TaskScheduleBlueprintFromAgrr.integer_value(task["task_id"])
        template = template_for_task(task_id)
        agricultural_task_id = agricultural_task_id_for(task_id, template)

        Domain::Crop::TaskScheduleBlueprintFromAgrr.general_row(
          crop_id: crop.id,
          task: task,
          agricultural_task_id: agricultural_task_id,
          template_description: template&.description,
          template_weather_dependency: template&.weather_dependency,
          template_time_per_sqm: template&.time_per_sqm
        )
      end

      def build_fertilizer_blueprint(entry, index)
        task_id = Domain::Crop::TaskScheduleBlueprintFromAgrr.integer_value(entry["task_id"])
        template = template_for_task(task_id)
        agricultural_task_id = agricultural_task_id_for(task_id, template)

        Domain::Crop::TaskScheduleBlueprintFromAgrr.fertilizer_row(
          crop_id: crop.id,
          entry: entry,
          index: index,
          agricultural_task_id: agricultural_task_id,
          template_description: template&.description,
          template_weather_dependency: template&.weather_dependency,
          template_time_per_sqm: template&.time_per_sqm
        )
      end

      def template_lookup
        @template_lookup ||= templates.each_with_object({}) do |template, memo|
          if template.agricultural_task_id.present?
            memo[template.agricultural_task_id] = template
            memo[template.agricultural_task_id.to_s] = template
          end
        end
      end

      def template_for_task(task_id)
        return nil if task_id.nil?

        template_lookup[task_id] || template_lookup[task_id.to_s]
      end

      def agricultural_task_id_for(task_id, template)
        agricultural_task = template&.agricultural_task || ::AgriculturalTask.find_by(id: task_id)
        agricultural_task&.id
      end
    end
  end
end
