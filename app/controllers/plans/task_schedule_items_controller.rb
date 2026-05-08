# frozen_string_literal: true

module Plans
  class TaskScheduleItemsController < ApplicationController
    before_action :authenticate_user!

    def create
      raw = params[:task_schedule_item]
      unless raw.is_a?(ActionController::Parameters)
        task_schedule_item_json_presenter.on_parameter_missing
        return
      end
      if raw.to_unsafe_h.blank?
        task_schedule_item_json_presenter.on_parameter_missing
        return
      end

      permitted = raw.permit(
        :field_cultivation_id,
        :name,
        :cultivation_plan_crop_id,
        :agricultural_task_id,
        :crop_task_template_id,
        :task_type,
        :description,
        :scheduled_date,
        :stage_name,
        :stage_order,
        :priority,
        :weather_dependency,
        :time_per_sqm,
        :amount,
        :amount_unit
      )
      CompositionRoot.task_schedule_item_create_interactor(output_port: task_schedule_item_json_presenter).call(
        user_id: current_user.id,
        plan_id: task_schedule_route_plan_id,
        attributes: permitted.to_unsafe_h
      )
    end

    def update
      raw = params[:task_schedule_item]
      unless raw.is_a?(ActionController::Parameters)
        task_schedule_item_json_presenter.on_parameter_missing
        return
      end
      if raw.to_unsafe_h.blank?
        task_schedule_item_json_presenter.on_parameter_missing
        return
      end

      permitted = raw.permit(
        :scheduled_date,
        :name,
        :priority,
        :weather_dependency,
        :amount,
        :amount_unit,
        :time_per_sqm
      )
      CompositionRoot.task_schedule_item_update_interactor(output_port: task_schedule_item_json_presenter).call(
        user_id: current_user.id,
        plan_id: task_schedule_route_plan_id,
        item_id: params[:id],
        attributes: permitted.to_unsafe_h
      )
    end

    def destroy
      fallback_location = plan_task_schedule_path(task_schedule_route_plan_id)
      presenter = Presenters::Plans::TaskScheduleItemDestroyPresenter.new(
        view: self,
        logger: CompositionRoot.logger,
        fallback_location: fallback_location
      )
      CompositionRoot.task_schedule_item_schedule_deletion_undo_interactor(
        json_output_port: task_schedule_item_json_presenter,
        undo_output_port: presenter,
        translator: CompositionRoot.translator
      ).call(
        user_id: current_user.id,
        plan_id: task_schedule_route_plan_id.to_i,
        item_id: params[:id].to_i
      )
    end

    def complete
      raw = params[:completion]
      unless raw.is_a?(ActionController::Parameters)
        task_schedule_item_json_presenter.on_parameter_missing
        return
      end

      permitted = raw.permit(:actual_date, :notes)

      CompositionRoot.task_schedule_item_complete_interactor(output_port: task_schedule_item_json_presenter).call(
        user_id: current_user.id,
        plan_id: task_schedule_route_plan_id,
        item_id: params[:id],
        completion_params: permitted.to_unsafe_h
      )
    end

    private

    def task_schedule_item_json_presenter
      Presenters::Plans::TaskScheduleItemJsonPresenter.new(view: self)
    end

    def task_schedule_route_plan_id
      params[:plan_id].presence || request.path_parameters[:plan_id]
    end
  end
end
