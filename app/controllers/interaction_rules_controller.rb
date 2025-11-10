# frozen_string_literal: true

class InteractionRulesController < ApplicationController
  before_action :set_interaction_rule, only: [:show, :edit, :update, :destroy]

  # GET /interaction_rules
  def index
    if admin_user?
      # 管理者: 自分のルール + 参照ルール
      @interaction_rules = InteractionRule.where("user_id = ? OR is_reference = ?", current_user.id, true).recent
      @reference_rules = InteractionRule.reference.recent
    else
      # 一般ユーザー: 自分のルールのみ（参照ルールは非表示）
      @interaction_rules = InteractionRule.where(user_id: current_user.id).recent
      @reference_rules = []
    end
  end

  # GET /interaction_rules/:id
  def show
  end

  # GET /interaction_rules/new
  def new
    @interaction_rule = InteractionRule.new
  end

  # GET /interaction_rules/:id/edit
  def edit
  end

  # POST /interaction_rules
  def create
    is_reference = interaction_rule_params[:is_reference] || false
    if is_reference && !admin_user?
      return redirect_to interaction_rules_path, alert: I18n.t('interaction_rules.flash.reference_only_admin')
    end

    @interaction_rule = InteractionRule.new(interaction_rule_params)
    @interaction_rule.user_id = nil if is_reference
    @interaction_rule.user_id ||= current_user.id

    if @interaction_rule.save
      redirect_to @interaction_rule, notice: I18n.t('interaction_rules.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /interaction_rules/:id
  def update
    if interaction_rule_params.key?(:is_reference) && !admin_user?
      return redirect_to @interaction_rule, alert: I18n.t('interaction_rules.flash.reference_flag_admin_only')
    end

    if @interaction_rule.update(interaction_rule_params)
      redirect_to @interaction_rule, notice: I18n.t('interaction_rules.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /interaction_rules/:id
  def destroy
    event = DeletionUndo::Manager.schedule(
      record: @interaction_rule,
      actor: current_user,
      toast_message: I18n.t(
        'interaction_rules.undo.toast',
        source: @interaction_rule.source_group,
        target: @interaction_rule.target_group
      )
    )

    render_deletion_undo_response(
      event,
      fallback_location: interaction_rules_path
    )
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
    render_deletion_failure(
      message: I18n.t('interaction_rules.flash.cannot_delete_in_use'),
      fallback_location: interaction_rules_path
    )
  rescue DeletionUndo::Error => e
    render_deletion_failure(
      message: I18n.t('interaction_rules.flash.delete_error', message: e.message),
      fallback_location: interaction_rules_path
    )
  rescue StandardError => e
    render_deletion_failure(
      message: I18n.t('interaction_rules.flash.delete_error', message: e.message),
      fallback_location: interaction_rules_path
    )
  end

  private

  def set_interaction_rule
    if admin_user?
      # 管理者: すべてのルールにアクセス可能
      @interaction_rule = InteractionRule.find(params[:id])
    else
      # 一般ユーザー: 自分のルールのみ
      @interaction_rule = InteractionRule.where(user_id: current_user.id).find(params[:id])
    end

    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（すべてのルールを編集可能）
      # - ユーザールールの所有者
      unless admin_user? || (!@interaction_rule.is_reference && @interaction_rule.user_id == current_user.id)
        redirect_to interaction_rules_path, alert: I18n.t('interaction_rules.flash.no_permission')
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 管理者（参照ルールも含めすべて閲覧可能）
      # - 自分のルール
      unless @interaction_rule.user_id == current_user.id || admin_user?
        redirect_to interaction_rules_path, alert: I18n.t('interaction_rules.flash.no_permission')
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to interaction_rules_path, alert: I18n.t('interaction_rules.flash.not_found')
  end

  def interaction_rule_params
    params.require(:interaction_rule).permit(
      :rule_type,
      :source_group,
      :target_group,
      :impact_ratio,
      :is_directional,
      :description,
      :is_reference
    )
  end
end

