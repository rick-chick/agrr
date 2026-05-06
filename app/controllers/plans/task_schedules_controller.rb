# frozen_string_literal: true

module Plans
  class TaskSchedulesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_cultivation_plan

    def show
      presenter = timeline_presenter
      Domain::CultivationPlan::Interactors::TaskScheduleTimelineInteractor.new(
        output_port: presenter,
        user_id: current_user.id,
        plan_id: @cultivation_plan.id,
        gateway: CompositionRoot.cultivation_plan_gateway,
        translator: CompositionRoot.translator,
        logger: CompositionRoot.logger,
        user_lookup: CompositionRoot.user_lookup,
        clock: Time.zone
      ).call
      return if performed?

      payload = presenter.as_json
      respond_to do |format|
        format.html do
          @timeline_initial_state = payload.deep_stringify_keys
        end
        format.json do
          render json: payload
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
      @timeline_presenter ||= Presenters::Html::Plans::TaskScheduleTimelinePresenter.new(
        view: self,
        params: timeline_params
      )
    end

    def timeline_params
      params.to_unsafe_h.slice("week_start", "field_cultivation_id", "category").symbolize_keys
    end
  end
end
