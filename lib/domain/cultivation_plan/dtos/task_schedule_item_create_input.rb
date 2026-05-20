# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 作業予定アイテム作成（Plans API）。Strong params 相当の Hash から組み立てる。
      class TaskScheduleItemCreateInput
        attr_reader :field_cultivation_id, :name, :cultivation_plan_crop_id, :agricultural_task_id,
                    :crop_task_template_id, :task_type, :description, :scheduled_date,
                    :stage_name, :stage_order, :priority, :weather_dependency,
                    :time_per_sqm, :amount, :amount_unit

        def initialize(
          field_cultivation_id:,
          name:,
          cultivation_plan_crop_id:,
          agricultural_task_id:,
          crop_task_template_id:,
          task_type:,
          description:,
          scheduled_date:,
          stage_name:,
          stage_order:,
          priority:,
          weather_dependency:,
          time_per_sqm:,
          amount:,
          amount_unit:
        )
          @field_cultivation_id = field_cultivation_id
          @name = name
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @agricultural_task_id = agricultural_task_id
          @crop_task_template_id = crop_task_template_id
          @task_type = task_type
          @description = description
          @scheduled_date = scheduled_date
          @stage_name = stage_name
          @stage_order = stage_order
          @priority = priority
          @weather_dependency = weather_dependency
          @time_per_sqm = time_per_sqm
          @amount = amount
          @amount_unit = amount_unit
        end

        def self.from_params(raw)
          h = Domain::Shared.symbolize_keys(raw.to_h)
          new(
            field_cultivation_id: h[:field_cultivation_id],
            name: h[:name],
            cultivation_plan_crop_id: h[:cultivation_plan_crop_id],
            agricultural_task_id: h[:agricultural_task_id],
            crop_task_template_id: h[:crop_task_template_id],
            task_type: h[:task_type],
            description: h[:description],
            scheduled_date: h[:scheduled_date],
            stage_name: h[:stage_name],
            stage_order: h[:stage_order],
            priority: h[:priority],
            weather_dependency: h[:weather_dependency],
            time_per_sqm: h[:time_per_sqm],
            amount: h[:amount],
            amount_unit: h[:amount_unit]
          )
        end

        def to_create_params_hash
          {
            field_cultivation_id: field_cultivation_id,
            name: name,
            cultivation_plan_crop_id: cultivation_plan_crop_id,
            agricultural_task_id: agricultural_task_id,
            crop_task_template_id: crop_task_template_id,
            task_type: task_type,
            description: description,
            scheduled_date: scheduled_date,
            stage_name: stage_name,
            stage_order: stage_order,
            priority: priority,
            weather_dependency: weather_dependency,
            time_per_sqm: time_per_sqm,
            amount: amount,
            amount_unit: amount_unit
          }
        end
      end
    end
  end
end
