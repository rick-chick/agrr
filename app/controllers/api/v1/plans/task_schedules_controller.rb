# frozen_string_literal: true

module Api
  module V1
    module Plans
      # GET /api/v1/plans/:id/task_schedule — Angular 作業予定画面と同一 JSON（Html::TaskScheduleTimelinePresenter）
      class TaskSchedulesController < BaseController
        def show
          presenter = timeline_presenter
          Domain::CultivationPlan::Interactors::TaskScheduleTimelineInteractor.new(
            output_port: presenter,
            user_id: current_user.id,
            plan_id: params[:id],
            gateway: CompositionRoot.cultivation_plan_gateway,
            translator: CompositionRoot.translator,
            logger: CompositionRoot.logger,
            user_lookup: CompositionRoot.user_lookup,
            clock: Time.zone
          ).call
          return if performed?

          render json: presenter.as_json
        end

        private

        def timeline_presenter
          @timeline_presenter ||= Adapters::CultivationPlan::Presenters::TaskScheduleTimelinePresenter.new(
            view: self,
            params: timeline_params
          )
        end

        def timeline_params
          params.to_unsafe_h.slice("week_start", "field_cultivation_id", "category").symbolize_keys
        end
      end
    end
  end
end
