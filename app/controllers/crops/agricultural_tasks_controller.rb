# frozen_string_literal: true

module Crops
  class AgriculturalTasksController < ApplicationController
    before_action :set_crop

    # GET /crops/:crop_id/agricultural_tasks
    def index
      # この作物に関連付けられている作業を取得（アクセス権限のある作業のみ）
      # 参照作業または自分の作業のみ表示
      @agricultural_tasks = @crop.agricultural_tasks.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
      # 参照作業も選択可能にするため、利用可能な作業を取得（管理者も参照作業と自分の作業のみ）
      @available_agricultural_tasks = AgriculturalTask.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    end

    # GET /crops/:crop_id/agricultural_tasks/new
    def new
      # 既存の作業を選択する場合
      @agricultural_task = AgriculturalTask.new
      
      # この作物にまだ関連付けられていない作業のリスト（参照作業または自分の作業のみ）
      available_tasks = AgriculturalTask.where("is_reference = ? OR user_id = ?", true, current_user.id)
      @unassociated_agricultural_tasks = available_tasks.where.not(id: @crop.agricultural_task_ids).recent
    end

    # POST /crops/:crop_id/agricultural_tasks
    def create
      # 既存の作業を選択して関連付ける場合
      if params[:agricultural_task_id].present?
        existing_task = AgriculturalTask.find_by(id: params[:agricultural_task_id])
        if existing_task
          # 権限チェック: 選択した作業が利用可能か確認
          unless can_access_agricultural_task?(existing_task)
            redirect_to crop_agricultural_tasks_path(@crop), alert: I18n.t('crops.agricultural_tasks.flash.no_permission')
            return
          end
          
          # 既に関連付けられていないかチェック
          unless @crop.agricultural_tasks.include?(existing_task)
            @crop.agricultural_tasks << existing_task
            redirect_to crop_agricultural_tasks_path(@crop), notice: I18n.t('crops.agricultural_tasks.flash.associated')
            return
          else
            redirect_to crop_agricultural_tasks_path(@crop), alert: I18n.t('crops.agricultural_tasks.flash.already_associated')
            return
          end
        end
      end

      # 新しい作業を作成する場合は、通常のagricultural_tasksコントローラーにリダイレクト
      redirect_to new_agricultural_task_path, notice: I18n.t('crops.agricultural_tasks.flash.redirect_to_create')
    end

    private

    def set_crop
      @crop = Crop.find(params[:crop_id])
      
      # 作物へのアクセス権限チェック
      # 管理者も参照作物と自身が作成した作物のみアクセス可能
      unless @crop.is_reference || @crop.user_id == current_user.id || admin_user?
        redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to crops_path, alert: I18n.t('crops.flash.not_found')
    end

    def can_access_agricultural_task?(task)
      if admin_user?
        task.is_reference || task.user_id == current_user.id
      else
        task.user_id == current_user.id && !task.is_reference
      end
    end
  end
end


