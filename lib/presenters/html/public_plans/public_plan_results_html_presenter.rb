# frozen_string_literal: true

module Presenters
  module Html
    module PublicPlans
      class PublicPlanResultsHtmlPresenter < Domain::CultivationPlan::Ports::PublicPlanResultsHtmlOutputPort
        def initialize(view:)
          @view = view
        end

        def on_not_found
          @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.not_found")
        end

        def redirect_to_optimizing
          @view.redirect_to @view.optimizing_public_plans_path
        end

        def on_success(read_model)
          @view.instance_variable_set(:@public_plan_results, read_model)
          @view.instance_variable_set(:@show_schedule_warning, read_model.show_schedule_warning)
          @view.instance_variable_set(:@gantt_embed, {
            plan_id: read_model.plan_id,
            planning_start_date: read_model.planning_start_date,
            planning_end_date: read_model.planning_end_date,
            gantt_cultivation_rows: read_model.gantt_cultivation_rows,
            gantt_field_rows: read_model.gantt_field_rows,
            crop_palette_embed: read_model.crop_palette_embed
          })
        end
      end
    end
  end
end
