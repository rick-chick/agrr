# frozen_string_literal: true

module Crops
  class TaskScheduleBlueprintsController < ApplicationController
    before_action :set_crop
    before_action :set_blueprint, only: [:update_position]

    # PATCH /crops/:crop_id/task_schedule_blueprints/:id/update_position
    def update_position
      unless can_edit_crop?
        return render json: { error: I18n.t('crops.flash.no_permission') }, status: :forbidden
      end

      gdd_trigger = params[:gdd_trigger]&.to_f
      priority = params[:priority]&.to_i

      # バリデーション
      if gdd_trigger && gdd_trigger < 0
        return render json: { error: 'gdd_trigger must be non-negative' }, status: :bad_request
      end

      if priority && priority < 0
        return render json: { error: 'priority must be non-negative' }, status: :bad_request
      end

      # 更新
      @blueprint.gdd_trigger = gdd_trigger if gdd_trigger
      @blueprint.priority = priority if priority

      if @blueprint.save
        # gdd_triggerとpriorityでソートし直して、priorityを再割り当て
        reorder_priorities
        
        # 再読み込みして最新のpriorityを取得
        @blueprint.reload
        
        render json: {
          id: @blueprint.id,
          gdd_trigger: @blueprint.gdd_trigger.to_f,
          priority: @blueprint.priority,
          message: I18n.t('crops.flash.blueprint_position_updated')
        }
      else
        render json: { error: @blueprint.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error("❌ [TaskScheduleBlueprintsController] Failed to update position: #{e.class} #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: I18n.t('crops.flash.blueprint_update_failed') }, status: :internal_server_error
    end

    private

    def set_crop
      @crop = Crop.find(params[:crop_id])
      unless can_view_crop?
        redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
      end
    end

    def set_blueprint
      @blueprint = @crop.crop_task_schedule_blueprints.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: I18n.t('crops.flash.blueprint_not_found') }, status: :not_found
    end

    def can_edit_crop?
      admin_user? || (!@crop.is_reference && @crop.user_id == current_user.id)
    end

    def can_view_crop?
      @crop.is_reference || @crop.user_id == current_user.id || admin_user?
    end

    # gdd_triggerとpriorityでソートし直して、priorityを再割り当て
    def reorder_priorities
      blueprints = @crop.crop_task_schedule_blueprints
                        .order(:gdd_trigger, :priority, :id)
      
      blueprints.each_with_index do |blueprint, index|
        blueprint.update_column(:priority, index + 1) if blueprint.priority != index + 1
      end
    end
  end
end

