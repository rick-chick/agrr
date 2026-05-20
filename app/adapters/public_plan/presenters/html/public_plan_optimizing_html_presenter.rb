# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      module Html
        class PublicPlanOptimizingHtmlPresenter < Domain::CultivationPlan::Ports::PlanOptimizingStatusOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(dto)
            if dto.completed?
              @view.redirect_to @view.public_plans_results_path
              return
            end

            if dto.failed?
              @view.redirect_to(
                @view.public_plans_results_path,
                alert: I18n.t("public_plans.optimizing.error.title")
              )
              return
            end

            @view.instance_variable_set(:@public_plan_optimizing, dto)
          end

          def on_failure(error_dto)
            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            @view.redirect_to @view.public_plans_path, alert: msg
          end
        end
      end
    end
  end
end
