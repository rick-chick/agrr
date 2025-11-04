# frozen_string_literal: true

class AgriculturalTasksController < ApplicationController
  before_action :set_agricultural_task, only: [:show, :edit, :update, :destroy]

  # GET /agricultural_tasks
  def index
    # 管理者は自身のタスクと参照タスクを表示、一般ユーザーは自身のタスクのみ表示
    if admin_user?
      @agricultural_tasks = AgriculturalTask.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    else
      @agricultural_tasks = AgriculturalTask.where(user_id: current_user.id, is_reference: false).recent
    end
  end

  # GET /agricultural_tasks/:id
  def show
  end

  # GET /agricultural_tasks/new
  def new
    @agricultural_task = AgriculturalTask.new
    @required_tools_text = ''
    @available_crops = available_crops_for_user
  end

  # GET /agricultural_tasks/:id/edit
  def edit
    @required_tools_text = @agricultural_task.required_tools&.join("\n") || ''
    @available_crops = available_crops_for_user
  end

  # POST /agricultural_tasks
  def create
    # is_referenceをbooleanに変換（"0", "false", ""はfalseとして扱う）
    is_reference = ActiveModel::Type::Boolean.new.cast(agricultural_task_params[:is_reference]) || false
    if is_reference && !admin_user?
      return redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.reference_only_admin')
    end

    @agricultural_task = AgriculturalTask.new(agricultural_task_params.except(:required_tools))
    if is_reference
      @agricultural_task.user_id = nil
      @agricultural_task.is_reference = true
    else
      @agricultural_task.user_id = current_user.id
      @agricultural_task.is_reference = false
    end

    # required_toolsをJSON配列に変換
    @agricultural_task.required_tools = parse_required_tools(params[:agricultural_task][:required_tools]) || []
    @required_tools_text = params[:agricultural_task][:required_tools]

    if @agricultural_task.save
      # 作物の関連付けを更新
      update_crop_associations(@agricultural_task, params[:crop_ids])
      redirect_to agricultural_task_path(@agricultural_task), notice: I18n.t('agricultural_tasks.flash.created')
    else
      @available_crops = available_crops_for_user
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /agricultural_tasks/:id
  def update
    # is_referenceをbooleanに変換してチェック
    is_reference_changed = false
    new_is_reference = nil
    
    if agricultural_task_params.key?(:is_reference)
      new_is_reference = ActiveModel::Type::Boolean.new.cast(agricultural_task_params[:is_reference]) || false
      if new_is_reference != @agricultural_task.is_reference
        is_reference_changed = true
        if !admin_user?
          return redirect_to agricultural_task_path(@agricultural_task), alert: I18n.t('agricultural_tasks.flash.reference_flag_admin_only')
        end
      end
    end

    # required_toolsをJSON配列に変換
    params_hash = agricultural_task_params.except(:required_tools, :is_reference).to_h
    params_hash['required_tools'] = parse_required_tools(params[:agricultural_task][:required_tools]) || []
    @required_tools_text = params[:agricultural_task][:required_tools]

    # is_referenceが変更される場合、user_idも適切に設定
    if is_reference_changed
      if new_is_reference
        params_hash['is_reference'] = true
        params_hash['user_id'] = nil
      else
        params_hash['is_reference'] = false
        params_hash['user_id'] = current_user.id
      end
    end

    if @agricultural_task.update(params_hash)
      # 作物の関連付けを更新
      update_crop_associations(@agricultural_task, params[:crop_ids])
      redirect_to agricultural_task_path(@agricultural_task), notice: I18n.t('agricultural_tasks.flash.updated')
    else
      @available_crops = available_crops_for_user
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /agricultural_tasks/:id
  def destroy
    begin
      @agricultural_task.destroy
      redirect_to agricultural_tasks_path, notice: I18n.t('agricultural_tasks.flash.destroyed')
    rescue ActiveRecord::InvalidForeignKey => e
      # 外部参照制約エラーの場合
      redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.cannot_delete_in_use')
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.cannot_delete_in_use')
    rescue StandardError => e
      redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.delete_error', message: e.message)
    end
  end

  private

  def set_agricultural_task
    # 管理者は自身のタスクと参照タスクのみアクセス可能、一般ユーザーは自分のタスクのみアクセス可能
    if admin_user?
      @agricultural_task = AgriculturalTask.where("is_reference = ? OR user_id = ?", true, current_user.id).find(params[:id])
    else
      @agricultural_task = AgriculturalTask.where(user_id: current_user.id, is_reference: false).find(params[:id])
    end
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（参照タスクまたは自身のタスクを編集可能）
      # - 参照タスクでない場合、かつ所有者である場合（一般ユーザーが作成したタスク）
      unless admin_user? || (!@agricultural_task.is_reference && @agricultural_task.user_id == current_user.id)
        redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.no_permission')
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 管理者（参照タスクまたは自身のタスクを閲覧可能）
      # - 自分のタスク（一般ユーザー）
      unless admin_user? || (@agricultural_task.user_id == current_user.id && !@agricultural_task.is_reference)
        redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.no_permission')
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.not_found')
  end

  def agricultural_task_params
    params.require(:agricultural_task).permit(
      :name,
      :description,
      :time_per_sqm,
      :weather_dependency,
      :required_tools,
      :skill_level,
      :is_reference
    )
  end

  # required_toolsを改行区切りの文字列からJSON配列に変換
  def parse_required_tools(tools_input)
    return [] if tools_input.blank?
    
    # 改行またはカンマで分割し、空白を削除
    tools = tools_input.to_s.split(/[\n,]/).map(&:strip).reject(&:blank?)
    tools
  end

  # ユーザーが作業に紐付け可能な作物を取得
  # 管理者: 参照作物と自身の作物
  # 一般ユーザー: 自身の作物のみ
  def available_crops_for_user
    if admin_user?
      Crop.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    else
      Crop.where(user_id: current_user.id, is_reference: false).recent
    end
  end

  # 作物の関連付けを更新
  def update_crop_associations(agricultural_task, crop_ids)
    crop_ids ||= []
    # 空文字列を除外
    crop_ids = crop_ids.reject(&:blank?).map(&:to_i)

    # 権限チェック: 追加する作物が利用可能か確認
    available_crop_ids = available_crops_for_user.pluck(:id)
    
    crop_ids.each do |crop_id|
      unless available_crop_ids.include?(crop_id)
        raise ActiveRecord::RecordNotFound, "Crop with id #{crop_id} is not available"
      end
    end

    # 関連付けを更新
    agricultural_task.crop_ids = crop_ids
  end
end

