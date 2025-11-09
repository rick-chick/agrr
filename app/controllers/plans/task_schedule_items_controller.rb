# frozen_string_literal: true

module Plans
  class TaskScheduleItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_cultivation_plan
    before_action :set_task_schedule_item, only: [:update, :destroy, :complete]
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

    def create
      item = TaskScheduleItem.transaction do
        attrs = create_params
        field_cultivation = @cultivation_plan.field_cultivations.find(attrs[:field_cultivation_id])
        category = 'general'
        validate_crop_selection!(field_cultivation, attrs[:cultivation_plan_crop_id])

        schedule = field_cultivation.task_schedules.find_or_create_by!(
          category: category,
          cultivation_plan: @cultivation_plan
        ) do |record|
          record.status = TaskSchedule::STATUSES[:active]
          record.source = 'manual_entry'
          record.generated_at = Time.zone.now
        end

        schedule.task_schedule_items.create!(build_create_attributes(attrs))
      end

      render json: serialize_item(item), status: :created
    end

    def update
      TaskScheduleItem.transaction do
        attributes = build_update_attributes(update_params)
        @task_schedule_item.update!(attributes)
      end

      render json: serialize_item(@task_schedule_item)
    end

    def destroy
      TaskScheduleItem.transaction do
        @task_schedule_item.update!(
          status: TaskScheduleItem::STATUSES[:cancelled],
          cancelled_at: Time.current
        )
      end

      head :no_content
    end

    def complete
      TaskScheduleItem.transaction do
        @task_schedule_item.update!(
          status: TaskScheduleItem::STATUSES[:completed],
          actual_date: completion_params[:actual_date],
          actual_notes: completion_params[:notes],
          completed_at: Time.current
        )
      end

      render json: serialize_item(@task_schedule_item)
    end

    private

    def set_cultivation_plan
      @cultivation_plan = current_user
        .cultivation_plans
        .plan_type_private
        .find(params[:plan_id])
    end

    def set_task_schedule_item
      @task_schedule_item = TaskScheduleItem
        .joins(task_schedule: :cultivation_plan)
        .where(task_schedules: { cultivation_plan_id: @cultivation_plan.id })
        .find(params[:id])
    end

    def create_params
      params.require(:task_schedule_item).permit(
        :field_cultivation_id,
        :name,
        :cultivation_plan_crop_id,
        :agricultural_task_id,
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
    end

    def update_params
      params.require(:task_schedule_item).permit(
        :scheduled_date,
        :name,
        :priority,
        :weather_dependency,
        :amount,
        :amount_unit,
        :time_per_sqm
      )
    end

    def completion_params
      permitted = params.require(:completion).permit(:actual_date, :notes)
      permitted[:actual_date] =
        if permitted[:actual_date].present?
          Date.parse(permitted[:actual_date])
        else
          Date.current
        end
      permitted
    end

    def build_create_attributes(raw_params)
      {
        task_type: raw_params[:task_type] || TaskScheduleItem::FIELD_WORK_TYPE,
        name: raw_params[:name],
        description: raw_params[:description],
        scheduled_date: raw_params[:scheduled_date],
        stage_name: raw_params[:stage_name],
        stage_order: raw_params[:stage_order],
        priority: raw_params[:priority],
        source: 'manual_entry',
        weather_dependency: raw_params[:weather_dependency],
        time_per_sqm: raw_params[:time_per_sqm],
        amount: raw_params[:amount],
        amount_unit: raw_params[:amount_unit],
        agricultural_task_id: raw_params[:agricultural_task_id].presence
      }
    end

    def validate_crop_selection!(field_cultivation, crop_id)
      expected_id = field_cultivation.cultivation_plan_crop_id
      return if expected_id.blank? && crop_id.blank?

      if expected_id.present? && crop_id.present? && expected_id == crop_id.to_i
        return
      end

      record = TaskScheduleItem.new
      record.errors.add(:base, I18n.t('plans.task_schedules.detail.actions.crop_required'))
      raise ActiveRecord::RecordInvalid, record
    end

    def build_update_attributes(raw_params)
      attributes = raw_params.to_h
      if attributes.key?('scheduled_date') && raw_params[:scheduled_date].present?
        new_date = Date.parse(raw_params[:scheduled_date]) rescue nil
        if new_date && @task_schedule_item.scheduled_date != new_date
          attributes['rescheduled_at'] = Time.current
          attributes['status'] = TaskScheduleItem::STATUSES[:rescheduled]
        end
      end
      attributes
    end

    def serialize_item(item)
      {
        id: item.id,
        name: item.name,
        scheduled_date: item.scheduled_date&.iso8601,
        status: item.status,
        category: item.task_schedule.category
      }
    end

    def handle_record_invalid(exception)
      record = exception.record
      errors = build_error_hash(record, exception.message)
      message = errors.values.flatten.compact.first || exception.message
      render json: { error: message, errors: errors }, status: :unprocessable_entity
    end

    def handle_record_not_found(_exception)
      render_error_response(:not_found, :not_found)
    end

    def handle_parameter_missing(_exception)
      render_error_response(:parameter_missing, :bad_request)
    end

    def render_error_response(message_key, status)
      message = I18n.t("controllers.plans.task_schedule_items.errors.#{message_key}")
      render json: { error: message, errors: { 'base' => [message] } }, status: status
    end

    def build_error_hash(record, fallback_message)
      return { 'base' => [fallback_message] } unless record&.respond_to?(:errors)

      errors = record.errors.to_hash(true).transform_keys(&:to_s)
      errors.transform_values! { |messages| Array(messages).compact }
      errors['base'] = Array(errors['base']).presence || [fallback_message]
      errors.delete_if { |_attribute, messages| messages.empty? }
      errors.presence || { 'base' => [fallback_message] }
    end
  end
end
