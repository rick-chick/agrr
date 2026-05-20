# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      class TaskScheduleItemMutationPresenter < Domain::CultivationPlan::Ports::TaskScheduleItemMutationOutputPort
        def initialize(view:)
          @view = view
        end

        def on_created(item_payload)
          @view.render json: item_payload, status: :created
        end

        def on_success(item_payload)
          @view.render json: item_payload
        end

        def on_record_invalid(errors:, fallback_message:)
          errors = build_error_hash(errors, fallback_message)
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

        def build_error_hash(errors_input, fallback_message)
          errors =
            if errors_input.is_a?(Hash)
              errors_input.transform_keys(&:to_s)
            elsif errors_input&.respond_to?(:to_hash)
              errors_input.to_hash(true).transform_keys(&:to_s)
            else
              return { "base" => [ fallback_message ] }
            end

          errors.transform_values! { |messages| Array(messages).compact }
          errors["base"] = Array(errors["base"]).presence || [ fallback_message ]
          errors.delete_if { |_attribute, messages| messages.empty? }
          errors.presence || { "base" => [ fallback_message ] }
        end
      end
    end
  end
end
