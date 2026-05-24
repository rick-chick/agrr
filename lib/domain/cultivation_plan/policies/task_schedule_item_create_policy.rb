# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      module TaskScheduleItemCreatePolicy
        CROP_REQUIRED_MESSAGE = "作物を選択してください"
        INVALID_TEMPLATE_MESSAGE = "選択した作業テンプレートは利用できません"
        NAME_REQUIRED_MESSAGE = "作業名を入力してください"
        INVALID_SCHEDULED_DATE_MESSAGE = "無効な日付が指定されました"

        module_function

        def validate_crop_selection!(field_cultivation_crop_id:, submitted_crop_id:)
          expected_id = field_cultivation_crop_id
          return if expected_id.blank? && submitted_crop_id.blank?
          return if expected_id.present? && submitted_crop_id.present? && expected_id == submitted_crop_id.to_i

          raise_record_invalid!(base: CROP_REQUIRED_MESSAGE)
        end

        # @param template [Domain::CultivationPlan::Dtos::TaskScheduleCropTaskTemplateSnapshot, nil]
        # @param field_crop_id [Integer, nil] cultivation_plan_crop 経由の crop_id
        def validate_template!(field_crop_id:, template:)
          return if template.nil?

          if field_crop_id.blank? || template.crop_id != field_crop_id
            raise_record_invalid!(base: INVALID_TEMPLATE_MESSAGE)
          end
        end

        def ensure_name_present!(name)
          return if Domain::Shared.present?(name)

          raise_record_invalid!(name: NAME_REQUIRED_MESSAGE)
        end

        def parse_scheduled_date!(raw_value)
          Date.iso8601(raw_value.to_s)
        rescue ArgumentError
          raise_record_invalid!(scheduled_date: INVALID_SCHEDULED_DATE_MESSAGE)
        end

        # @param raw_params [Hash] symbol または string キー
        # @param template [Domain::CultivationPlan::Dtos::TaskScheduleCropTaskTemplateSnapshot, nil]
        # @return [Hash] TaskScheduleItemMutationGateway#create に渡す永続化属性（シンボルキー）
        def build_create_attributes(raw_params, template:)
          params = Domain::Shared.symbolize_keys(raw_params.to_h)

          name = params[:name].presence || template&.name
          ensure_name_present!(name)

          task_type = if template
            template.task_type || Domain::AgriculturalTask::Constants::ScheduleItemTypes::FIELD_WORK
          else
            params[:task_type].presence || Domain::AgriculturalTask::Constants::ScheduleItemTypes::FIELD_WORK
          end

          {
            field_cultivation_id: params[:field_cultivation_id],
            task_type: task_type,
            name: name,
            description: params[:description].presence || template&.description,
            scheduled_date: params[:scheduled_date],
            stage_name: params[:stage_name],
            stage_order: params[:stage_order],
            priority: params[:priority],
            source: template ? "template_entry" : "manual_entry",
            weather_dependency: params[:weather_dependency].presence || template&.weather_dependency,
            time_per_sqm: params[:time_per_sqm].presence || template&.time_per_sqm,
            amount: params[:amount],
            amount_unit: params[:amount_unit],
            agricultural_task_id: params[:agricultural_task_id].presence || template&.agricultural_task_id,
            cultivation_plan_crop_id: params[:cultivation_plan_crop_id]
          }
        end

        def raise_record_invalid!(base: nil, name: nil, scheduled_date: nil)
          errors = {}
          errors["base"] = [ base ] if base
          errors["name"] = [ name ] if name
          errors["scheduled_date"] = [ scheduled_date ] if scheduled_date
          msg = errors.values.flatten.compact.first
          raise Domain::Shared::Exceptions::RecordInvalid.new(msg, errors: errors)
        end
        private_class_method :raise_record_invalid!
      end
    end
  end
end
