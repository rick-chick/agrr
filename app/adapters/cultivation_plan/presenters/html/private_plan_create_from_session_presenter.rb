# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Html
        class PrivatePlanCreateFromSessionPresenter < Domain::CultivationPlan::Ports::PrivatePlanCreateFromSessionOutputPort
          def initialize(
            view:,
            session_key:
          )
            @view = view
            @session_key = session_key
          end

          def on_missing_session
            @view.redirect_to @view.new_plan_path, alert: I18n.t("plans.errors.restart")
          end

          def on_restart
            @view.redirect_to @view.new_plan_path, alert: I18n.t("plans.errors.restart")
          end

          def on_no_crops_selected
            @view.flash.now[:alert] = I18n.t("plans.errors.select_crop")
            @view.render :select_crop, status: :unprocessable_entity
          end

          def on_existing_plan(plan_id:, plan_year:)
            alert =
              if plan_year.present?
                I18n.t("plans.errors.plan_already_exists", year: plan_year)
              else
                I18n.t("plans.errors.plan_already_exists_annual")
              end
            @view.redirect_to @view.plan_path(plan_id), alert: alert
          end

          def on_initialize_failed(message:)
            @view.redirect_to @view.new_plan_path, alert: message
          end

          def on_success(plan_id:)
            @view.session[@session_key] = { plan_id: plan_id }

            @view.redirect_to @view.optimizing_plan_path(plan_id), notice: I18n.t("plans.messages.plan_created")
          end
        end
      end
    end
  end
end
