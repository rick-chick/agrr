# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class PublicPlanCreateHtmlPresenter < Domain::PublicPlan::Ports::PublicPlanCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(success_dto)
          key = @view.class.session_key
          sess = (@view.session[key] || {}).with_indifferent_access
          @view.session[key] = sess.merge(plan_id: success_dto.plan_id)
          @view.redirect_to @view.optimizing_public_plans_path
        end

        def on_no_crops_failure(_view_context)
          @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.select_crop")
        end

        def on_failure(failure_dto)
          message = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s
          @view.redirect_to @view.public_plans_path, alert: failure_alert_for_message(message)
        end

        private

        def failure_alert_for_message(msg)
          case msg
          when "Farm not found", "Invalid farm size", "Invalid total area"
            I18n.t("public_plans.errors.restart")
          when "No crops selected"
            I18n.t("public_plans.errors.select_crop")
          else
            if msg.to_s.start_with?("Failed to create cultivation plan")
              I18n.t("public_plans.errors.restart")
            else
              msg
            end
          end
        end
      end
    end
  end
end
