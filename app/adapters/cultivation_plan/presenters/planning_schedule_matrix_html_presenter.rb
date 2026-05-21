# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      class PlanningScheduleMatrixHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(dto)
          @view.session[:planning_schedule_farm_id] = dto.session_farm_id
          @view.session[:planning_schedule_field_ids] = dto.session_field_ids

          @view.instance_variable_set(:@farm, dto.farm)
          @view.instance_variable_set(:@selected_fields, dto.selected_fields)
          @view.instance_variable_set(:@periods, dto.periods)
          @view.instance_variable_set(:@cultivations_by_field, dto.cultivations_by_field)
          @view.instance_variable_set(:@start_year, dto.start_year)
          @view.instance_variable_set(:@end_year, dto.end_year)
          @view.instance_variable_set(:@year_range, dto.year_range)
          @view.instance_variable_set(:@years_range, dto.years_range)
          @view.instance_variable_set(:@granularity, dto.granularity)
          @view.instance_variable_set(
            :@schedule_presenter,
            Adapters::CultivationPlan::Presenters::PlanningScheduleHtmlPresenter.new(periods: dto.periods)
          )
        end

        def on_redirect_fields_selection(alert_key:)
          @view.redirect_to @view.fields_selection_planning_schedules_path, alert: @view.t(alert_key)
        end
      end
    end
  end
end
