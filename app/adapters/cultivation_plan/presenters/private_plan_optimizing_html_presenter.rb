# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      class PrivatePlanOptimizingHtmlPresenter < Domain::CultivationPlan::Ports::PlanOptimizingStatusOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(dto)
          if dto.completed?
            @view.redirect_to @view.spa_plan_detail_url(dto.id), allow_other_host: true
            return
          end

          if dto.failed?
            @view.redirect_to(
              @view.spa_plan_detail_url(dto.id),
              allow_other_host: true,
              alert: I18n.t("plans.optimizing.error.title")
            )
            return
          end

          @view.instance_variable_set(:@private_plan_optimizing, dto)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.redirect_to @view.plans_path, alert: msg
        end
      end
    end
  end
end
