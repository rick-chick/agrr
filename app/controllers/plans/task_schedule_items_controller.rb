# frozen_string_literal: true

module Plans
  class TaskScheduleItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_cultivation_plan
    before_action :set_task_schedule_item, only: [:update, :destroy, :complete]
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

    AMOUNT_NUMERATOR_UNITS = {
      'ml' => { base: :liter, factor: BigDecimal('0.001') },
      'l' => { base: :liter, factor: BigDecimal('1') },
      'g' => { base: :gram, factor: BigDecimal('1') },
      'kg' => { base: :gram, factor: BigDecimal('1000') }
    }.freeze

    AREA_UNITS = {
      'm2' => BigDecimal('1'),
      '㎡' => BigDecimal('1'),
      'a' => BigDecimal('100'),
      '10a' => BigDecimal('1000'),
      'ha' => BigDecimal('10000')
    }.freeze

    CONVERSION_TOLERANCE = BigDecimal('0.0001')
    private_constant :AMOUNT_NUMERATOR_UNITS, :AREA_UNITS, :CONVERSION_TOLERANCE
    class UnitConversionError < StandardError; end

    def create
      item = TaskScheduleItem.transaction do
        raw_params = create_params
        attrs = raw_params.to_h.symbolize_keys
        field_cultivation = @cultivation_plan.field_cultivations.find(attrs[:field_cultivation_id])
        category = 'general'
        validate_crop_selection!(field_cultivation, attrs[:cultivation_plan_crop_id])
        template = find_task_template(attrs[:crop_task_template_id])
        validate_template!(field_cultivation, template)

        schedule = field_cultivation.task_schedules.find_or_create_by!(
          category: category,
          cultivation_plan: @cultivation_plan
        ) do |record|
          record.status = TaskSchedule::STATUSES[:active]
          record.source = 'manual_entry'
          record.generated_at = Time.zone.now
        end

        schedule.task_schedule_items.create!(
          build_create_attributes(attrs.except(:crop_task_template_id), template: template)
        )
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
      fallback_location = plan_task_schedule_path(@cultivation_plan)

      @task_schedule_item.validate!
      event = DeletionUndo::Manager.schedule(
        record: @task_schedule_item,
        actor: current_user,
        toast_message: I18n.t(
          'plans.task_schedule_items.undo.toast',
          name: @task_schedule_item.name
        )
      )

      render_deletion_undo_response(
        event,
        fallback_location: fallback_location
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.warn("[Plans::TaskScheduleItemsController] destroy failed: #{e.class} #{e.message}")
      render_deletion_failure(
        message: I18n.t('controllers.plans.task_schedule_items.errors.cancel_failed'),
        fallback_location: fallback_location
      )
    rescue DeletionUndo::Error => e
      Rails.logger.error("[Plans::TaskScheduleItemsController] undo scheduling error: #{e.class} #{e.message}")
      render_deletion_failure(
        message: I18n.t(
          'controllers.plans.task_schedule_items.errors.undo_failed',
          message: e.message
        ),
        fallback_location: fallback_location
      )
    rescue StandardError => e
      Rails.logger.error("[Plans::TaskScheduleItemsController] unexpected destroy error: #{e.class} #{e.message}")
      render_deletion_failure(
        message: I18n.t('controllers.plans.task_schedule_items.errors.cancel_failed'),
        fallback_location: fallback_location
      )
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

    def build_create_attributes(raw_params, template: nil)
      params = raw_params.to_h.symbolize_keys

      name = params[:name].presence || template&.name
      ensure_name_present!(name)

      task_type = if template
                    template.task_type || TaskScheduleItem::FIELD_WORK_TYPE
                  else
                    params[:task_type].presence || TaskScheduleItem::FIELD_WORK_TYPE
                  end

      {
        task_type: task_type,
        name: name,
        description: params[:description].presence || template&.description,
        scheduled_date: params[:scheduled_date],
        stage_name: params[:stage_name],
        stage_order: params[:stage_order],
        priority: params[:priority],
        source: template ? 'template_entry' : 'manual_entry',
        weather_dependency: params[:weather_dependency].presence || template&.weather_dependency,
        time_per_sqm: params[:time_per_sqm].presence || template&.time_per_sqm,
        amount: params[:amount],
        amount_unit: params[:amount_unit],
        agricultural_task_id: params[:agricultural_task_id].presence || template&.agricultural_task_id
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

    def validate_template!(field_cultivation, template)
      return unless template

      crop_id = field_cultivation&.cultivation_plan_crop&.crop_id
      if crop_id.blank? || template.crop_id != crop_id
        record = TaskScheduleItem.new
        message = I18n.t(
          'controllers.plans.task_schedule_items.errors.invalid_template',
          default: '選択した作業テンプレートは利用できません'
        )
        record.errors.add(:base, message)
        raise ActiveRecord::RecordInvalid, record
      end
    end

    def build_update_attributes(raw_params)
      attributes = raw_params.to_h
      if attributes.key?('scheduled_date') && raw_params[:scheduled_date].present?
        new_date =
          begin
            Date.iso8601(raw_params[:scheduled_date].to_s)
          rescue ArgumentError
            record = TaskScheduleItem.new
            record.errors.add(
              :scheduled_date,
              I18n.t(
                'controllers.plans.task_schedule_items.errors.invalid_scheduled_date',
                default: '無効な日付が指定されました'
              )
            )
            raise ActiveRecord::RecordInvalid, record
          end

        attributes['scheduled_date'] = new_date

        if @task_schedule_item.scheduled_date != new_date
          attributes['rescheduled_at'] = Time.current
          attributes['status'] = TaskScheduleItem::STATUSES[:rescheduled]
        end
      end
      apply_amount_unit_conversion(attributes)
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

    def find_task_template(template_id)
      return nil if template_id.blank?

      CropTaskTemplate.includes(:agricultural_task, :crop).find(template_id)
    end

    def ensure_name_present!(name)
      return if name.present?

      record = TaskScheduleItem.new
      message = I18n.t(
        'plans.task_schedules.detail.actions.name_required',
        default: '作業名を入力してください'
      )
      record.errors.add(:name, message)
      raise ActiveRecord::RecordInvalid, record
    end

    def apply_amount_unit_conversion(attributes)
      return attributes unless attributes.key?('amount_unit')

      new_unit = attributes['amount_unit']
      current_unit = @task_schedule_item.amount_unit
      return attributes if new_unit.blank? || current_unit.blank? || new_unit == current_unit

      current_amount = @task_schedule_item.amount
      return attributes if current_amount.nil?

      amount_param = attributes['amount']
      if amount_param.present?
        param_amount = decimal_from(amount_param)
        return attributes if param_amount.nil?
        return attributes unless approx_equal?(param_amount, decimal_from(current_amount))
      end

      attributes['amount'] = convert_per_area_amount(
        decimal_from(current_amount),
        from: current_unit,
        to: new_unit
      )
      attributes
    rescue UnitConversionError => e
      Rails.logger.warn("[Plans::TaskScheduleItemsController] Amount unit conversion skipped: #{e.message}")
      attributes
    end

    def convert_per_area_amount(amount, from:, to:)
      amount = decimal_from(amount)
      raise UnitConversionError, 'amount is required for conversion' if amount.nil?

      from_numerator, from_area = parse_per_area_unit(from)
      to_numerator, to_area = parse_per_area_unit(to)

      from_meta = AMOUNT_NUMERATOR_UNITS[from_numerator]
      to_meta = AMOUNT_NUMERATOR_UNITS[to_numerator]

      raise UnitConversionError, "unsupported amount unit: #{from}" if from_meta.nil?
      raise UnitConversionError, "unsupported amount unit: #{to}" if to_meta.nil?
      unless from_meta[:base] == to_meta[:base]
        raise UnitConversionError, "incompatible amount units: #{from} -> #{to}"
      end

      from_area_factor = area_unit_factor(from_area)
      to_area_factor = area_unit_factor(to_area)

      amount_in_base = amount * from_meta[:factor]
      amount_per_m2 = amount_in_base / from_area_factor
      target_in_base = amount_per_m2 * to_area_factor
      target_in_base / to_meta[:factor]
    end

    def parse_per_area_unit(unit)
      parts = unit.to_s.split('/')
      raise UnitConversionError, "invalid amount_unit format: #{unit}" if parts.size != 2

      [normalize_amount_unit(parts[0]), normalize_area_unit(parts[1])]
    end

    def normalize_amount_unit(unit)
      unit.to_s.strip.downcase
    end

    def normalize_area_unit(unit)
      value = unit.to_s.strip.downcase
      return 'm2' if value == '㎡'

      value
    end

    def area_unit_factor(unit)
      factor = AREA_UNITS[normalize_area_unit(unit)]
      raise UnitConversionError, "unsupported area unit: #{unit}" if factor.nil?

      factor
    end

    def decimal_from(value)
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def approx_equal?(left, right)
      return false if left.nil? || right.nil?

      (left - right).abs <= CONVERSION_TOLERANCE
    end
  end
end
