# frozen_string_literal: true

module Crops
  class AgriculturalTasksController < ApplicationController
    before_action :authenticate_user!
    before_action :set_crop
    before_action :set_template, only: [:edit, :update, :destroy]

    # GET /crops/:crop_id/agricultural_tasks
    def index
      @templates = @crop.crop_task_templates.includes(:agricultural_task).order(:name)
      @available_agricultural_tasks = selectable_agricultural_tasks
    end

    # GET /crops/:crop_id/agricultural_tasks/new
    def new
      # 既存の作業を選択する場合
      @agricultural_task = AgriculturalTask.new
      @unassociated_agricultural_tasks = selectable_agricultural_tasks
    end

    def edit
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
          
          if template_exists_for?(existing_task)
            redirect_to crop_agricultural_tasks_path(@crop), alert: I18n.t('crops.agricultural_tasks.flash.template_already_exists')
            return
          end

          template = @crop.crop_task_templates.create!(
            agricultural_task: existing_task,
            source_agricultural_task_id: existing_task.source_agricultural_task_id,
            name: existing_task.name,
            description: existing_task.description,
            time_per_sqm: existing_task.time_per_sqm,
            weather_dependency: existing_task.weather_dependency,
            required_tools: existing_task.required_tools,
            skill_level: existing_task.skill_level,
            task_type: existing_task.task_type,
            task_type_id: existing_task.task_type_id,
            is_reference: existing_task.is_reference
          )

          redirect_to crop_agricultural_tasks_path(@crop),
                      notice: I18n.t('crops.agricultural_tasks.flash.template_created')
          return
        end
      end

      # 新しい作業を作成する場合は、通常のagricultural_tasksコントローラーにリダイレクト
      redirect_to new_agricultural_task_path, notice: I18n.t('crops.agricultural_tasks.flash.redirect_to_create')
    end

    def update
      if @template.update(template_params)
        redirect_to crop_agricultural_tasks_path(@crop), notice: I18n.t('crops.agricultural_tasks.flash.template_updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @template.destroy!
      redirect_to crop_agricultural_tasks_path(@crop), notice: I18n.t('crops.agricultural_tasks.flash.template_deleted')
    end

    private

    def set_crop
      @crop = Crop.find(params[:crop_id])
    def set_template
      @template = @crop.crop_task_templates.find(params[:id])
    end

    def template_params
      params.require(:crop_task_template).permit(
        :name,
        :description,
        :time_per_sqm,
        :weather_dependency,
        :skill_level,
        required_tools: []
      )
    end
      
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

    def selectable_agricultural_tasks
      scope = AgriculturalTask.where("is_reference = ? OR user_id = ?", true, current_user.id)
      existing_task_ids = @crop.crop_task_templates.pluck(:agricultural_task_id).compact
      scope = scope.where.not(id: existing_task_ids) if existing_task_ids.any?
      scope.recent
    end

    def template_exists_for?(task)
      @crop.crop_task_templates.any? do |template|
        (template.agricultural_task_id.present? && template.agricultural_task_id == task.id) ||
          (template.source_agricultural_task_id.present? &&
           template.source_agricultural_task_id == task.source_agricultural_task_id)
      end
    end
  end
end






