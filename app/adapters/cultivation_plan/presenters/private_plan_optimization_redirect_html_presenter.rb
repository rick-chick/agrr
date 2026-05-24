# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      class PrivatePlanOptimizationRedirectHtmlPresenter < Domain::CultivationPlan::Ports::PrivatePlanOptimizationRedirectOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(dto)
          if dto.already_optimizing
            @view.redirect_to @view.spa_plan_detail_url(dto.plan_id),
              allow_other_host: true,
              alert: I18n.t("plans.errors.already_optimized")
          else
            @view.redirect_to @view.optimizing_plan_path(dto.plan_id),
                              notice: I18n.t("plans.messages.optimization_started")
          end
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.redirect_to @view.plans_path, alert: msg
        end
      end
    end
  end
end
