# frozen_string_literal: true

module Crops
  class TaskScheduleBlueprintsController < ApplicationController
    before_action :set_crop
    before_action :set_blueprint, only: [:update_position, :destroy]

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

    # DELETE /crops/:crop_id/task_schedule_blueprints/:id
    def destroy
      unless can_edit_crop?
        return render json: { error: I18n.t('crops.flash.no_permission') }, status: :forbidden
      end

      blueprint_id = @blueprint.id
      agricultural_task_id = @blueprint.agricultural_task_id
      
      @blueprint.destroy!
      @blueprint_id = blueprint_id

      # blueprintを削除した後、対応するtemplateも削除する必要がある
      # 同じagricultural_task_idに対応する他のblueprintが存在しない場合、templateも削除
      if agricultural_task_id.present?
        remaining_blueprints = @crop.crop_task_schedule_blueprints
                                      .where(agricultural_task_id: agricultural_task_id)
        
        if remaining_blueprints.empty?
          # 同じagricultural_task_idに対応するblueprintが存在しない場合、templateも削除
          template = @crop.crop_task_templates.find_by(agricultural_task_id: agricultural_task_id)
          if template
            Rails.logger.info("🗑️ [TaskScheduleBlueprintsController] Deleting template: template_id=#{template.id}, agricultural_task_id=#{agricultural_task_id}")
            template.destroy!
          end
        end
      end

      # @cropを再読み込みして、削除後の状態を反映
      @crop.reload

      # 利用可能な作業テンプレート情報を取得
      @available_agricultural_tasks = available_agricultural_tasks_for_crop(@crop)
      @selected_task_ids = selected_task_ids_for_crop(@crop)

      respond_to do |format|
        format.turbo_stream
        format.json { render json: { message: I18n.t('crops.flash.blueprint_deleted') } }
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove("blueprint-card-#{params[:id]}") }
        format.json { render json: { error: I18n.t('crops.flash.blueprint_not_found') }, status: :not_found }
      end
    rescue StandardError => e
      Rails.logger.error("❌ [TaskScheduleBlueprintsController] Failed to delete blueprint: #{e.class} #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("blueprint-card-#{@blueprint.id}", partial: 'crops/task_schedule_blueprints/error', locals: { error: I18n.t('crops.flash.blueprint_delete_failed') }) }
        format.json { render json: { error: I18n.t('crops.flash.blueprint_delete_failed') }, status: :internal_server_error }
      end
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

    # 作物に利用可能な農業タスクを取得
    def available_agricultural_tasks_for_crop(crop)
      # ユーザ作物であればそのユーザの作業のみ
      if !crop.is_reference && crop.user_id.present?
        tasks = AgriculturalTask.user_owned.where(user_id: crop.user_id)
        # 地域が設定されていればその地域も条件に追加
        tasks = tasks.where(region: crop.region) if crop.region.present?
        return tasks.order(:name)
      end
      
      # 参照作物であれば参照作業のみ
      if crop.is_reference
        tasks = AgriculturalTask.reference
        # 地域が設定されていればその地域も条件に追加
        tasks = tasks.where(region: crop.region) if crop.region.present?
        return tasks.order(:name)
      end
      
      # どちらでもない場合は空のコレクション
      AgriculturalTask.none
    end

    # 作物に既にテンプレートとして登録されているタスクIDを取得
    def selected_task_ids_for_crop(crop)
      crop.crop_task_templates.pluck(:agricultural_task_id).compact.uniq
    end
  end
end

