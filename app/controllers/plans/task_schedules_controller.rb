# frozen_string_literal: true

module Plans
  class TaskSchedulesController < ApplicationController
    before_action :authenticate_user!

    def show
      presenter = timeline_presenter
      Domain::CultivationPlan::Interactors::TaskScheduleTimelineInteractor.new(
        output_port: presenter,
        user_id: current_user.id,
        plan_id: params[:plan_id].to_i,
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
          @cultivation_plan = presenter.html_shell_plan
          @timeline_initial_state = payload.deep_stringify_keys
        end
        format.json do
          render json: payload
        end
      end
    end

    private

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
