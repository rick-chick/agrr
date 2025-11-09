# frozen_string_literal: true

module Plans
  class TaskSchedulesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_cultivation_plan

    def show
      respond_to do |format|
        format.html do
          @timeline_initial_state = timeline_presenter.as_json.deep_stringify_keys
        end
        format.json do
          render json: timeline_presenter.as_json
        end
      end
    end

    private

    def set_cultivation_plan
      @cultivation_plan = current_user
        .cultivation_plans
        .plan_type_private
        .find(params[:plan_id])
    end

    def timeline_presenter
      @timeline_presenter ||= TaskScheduleTimelinePresenter.new(@cultivation_plan, timeline_params)
    end

    def timeline_params
      params.to_unsafe_h.slice('week_start', 'field_cultivation_id', 'category').symbolize_keys
    end
  end
end


