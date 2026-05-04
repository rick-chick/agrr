# frozen_string_literal: true

module Plans
  class TaskScheduleItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_cultivation_plan
    before_action :set_task_schedule_item, only: [ :destroy ]

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
      fallback_location = plan_task_schedule_path(@cultivation_plan)
      presenter = Presenters::Plans::TaskScheduleItemDestroyPresenter.new(
        view: self,
        logger: CompositionRoot.logger,
        fallback_location: fallback_location
      )
      input = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
        record: @task_schedule_item,
        actor: current_user,
        toast_message: I18n.t(
          "plans.task_schedule_items.undo.toast",
          name: @task_schedule_item.name
        )
      )
      CompositionRoot.deletion_undo_schedule_interactor(output_port: presenter).call(input)
    end

    def complete
      raw = params[:completion]
      unless raw.is_a?(ActionController::Parameters)
        task_schedule_item_json_presenter.on_parameter_missing
        return
      end

      permitted = raw.permit(:actual_date, :notes)
      actual_date =
        if permitted[:actual_date].present?
          Date.parse(permitted[:actual_date])
        else
          Date.current
        end

      CompositionRoot.task_schedule_item_complete_interactor(output_port: task_schedule_item_json_presenter).call(
        user_id: current_user.id,
        plan_id: task_schedule_route_plan_id,
        item_id: params[:id],
        actual_date: actual_date,
        actual_notes: permitted[:notes],
        completed_at: Time.current
      )
    end

    private

    def task_schedule_item_json_presenter
      Presenters::Plans::TaskScheduleItemJsonPresenter.new(view: self)
    end

    def task_schedule_route_plan_id
      params[:plan_id].presence || request.path_parameters[:plan_id]
    end

    def set_cultivation_plan
      plan_id = task_schedule_route_plan_id
      @cultivation_plan = current_user
        .cultivation_plans
        .plan_type_private
        .find_by(id: plan_id)

      return if @cultivation_plan

      task_schedule_item_json_presenter.on_not_found
    end

    def set_task_schedule_item
      item_id = params[:id].presence || request.path_parameters[:id]
      @task_schedule_item = TaskScheduleItem
        .joins(task_schedule: :cultivation_plan)
        .where(task_schedules: { cultivation_plan_id: @cultivation_plan.id })
        .find_by(id: item_id)

      return if @task_schedule_item

      task_schedule_item_json_presenter.on_not_found
    end
  end
end
