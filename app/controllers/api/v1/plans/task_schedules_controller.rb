# frozen_string_literal: true

module Api
  module V1
    module Plans
      # GET /api/v1/plans/:id/task_schedule — Angular 作業予定画面と同一 JSON（Html::TaskScheduleTimelinePresenter）
      class TaskSchedulesController < BaseController
        before_action :set_cultivation_plan

        def show
          render json: timeline_presenter.as_json
        end

        private

        def set_cultivation_plan
          @cultivation_plan = PlanPolicy.find_private_owned!(current_user, params[:id])
        rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise ActiveRecord::RecordNotFound
        end

        def timeline_presenter
          @timeline_presenter ||= Presenters::Html::Plans::TaskScheduleTimelinePresenter.new(
            @cultivation_plan,
            timeline_params
          )
        end

        def timeline_params
          params.to_unsafe_h.slice("week_start", "field_cultivation_id", "category").symbolize_keys
        end
      end
    end
  end
end
