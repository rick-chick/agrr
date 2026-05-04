# frozen_string_literal: true

module Presenters
  module Plans
    class TaskScheduleItemJsonPresenter < Domain::CultivationPlan::Ports::TaskScheduleItemJsonOutputPort
      def initialize(view:)
        @view = view
      end

      def on_created(item_payload)
        @view.render json: item_payload, status: :created
      end

      def on_success(item_payload)
        @view.render json: item_payload
      end

      def on_record_invalid(record, fallback_message)
        errors = build_error_hash(record, fallback_message)
        message = errors.values.flatten.compact.first || fallback_message
        @view.render json: { error: message, errors: errors }, status: :unprocessable_entity
      end

      def on_not_found
        message = I18n.t("controllers.plans.task_schedule_items.errors.not_found")
        @view.render json: { error: message, errors: { "base" => [ message ] } }, status: :not_found
      end

      def on_parameter_missing
        message = I18n.t("controllers.plans.task_schedule_items.errors.parameter_missing")
        @view.render json: { error: message, errors: { "base" => [ message ] } }, status: :bad_request
      end

      private

      def build_error_hash(record, fallback_message)
        return { "base" => [ fallback_message ] } unless record&.respond_to?(:errors)

        errors = record.errors.to_hash(true).transform_keys(&:to_s)
        errors.transform_values! { |messages| Array(messages).compact }
        errors["base"] = Array(errors["base"]).presence || [ fallback_message ]
        errors.delete_if { |_attribute, messages| messages.empty? }
        errors.presence || { "base" => [ fallback_message ] }
      end
    end
  end
end
