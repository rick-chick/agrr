# frozen_string_literal: true

class InteractionRulesController < ApplicationController
  include DeletionUndoFlow
  before_action :set_interaction_rule, only: [:show, :edit, :update, :destroy]

  # GET /interaction_rules
  def index
    # 管理者は参照ルールも一覧に含め、別枠で参照ルール一覧も表示
    @interaction_rules = InteractionRulePolicy.visible_scope(current_user).recent
    @reference_rules =
      if admin_user?
        InteractionRule.reference.recent
      else
        []
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

    @interaction_rule, = InteractionRulePolicy.build_for_create(current_user, interaction_rule_params.to_h)

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

    if InteractionRulePolicy.apply_update!(current_user, @interaction_rule, interaction_rule_params.to_h)
      redirect_to @interaction_rule, notice: I18n.t('interaction_rules.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /interaction_rules/:id
  def destroy
    toast = I18n.t(
      'interaction_rules.undo.toast',
      source: @interaction_rule.source_group,
      target: @interaction_rule.target_group
    )

    schedule_deletion_with_undo(
      record: @interaction_rule,
      toast_message: toast,
      fallback_location: interaction_rules_path,
      in_use_message_key: 'interaction_rules.flash.cannot_delete_in_use',
      delete_error_message_key: 'interaction_rules.flash.delete_error'
    )
  end

  private

  def set_interaction_rule
    action = params[:action].to_sym

    @interaction_rule =
      if action.in?([:edit, :update, :destroy])
        InteractionRulePolicy.find_editable!(current_user, params[:id])
      else
        InteractionRulePolicy.find_visible!(current_user, params[:id])
      end
  rescue PolicyPermissionDenied
    redirect_to interaction_rules_path, alert: I18n.t('interaction_rules.flash.no_permission')
  rescue ActiveRecord::RecordNotFound
    redirect_to interaction_rules_path, alert: I18n.t('interaction_rules.flash.not_found')
  end

  def interaction_rule_params
    permitted = [
      :rule_type,
      :source_group,
      :target_group,
      :impact_ratio,
      :is_directional,
      :description,
      :is_reference
    ]
    
    # 管理者のみregionを許可
    permitted << :region if admin_user?
    
    params.require(:interaction_rule).permit(*permitted)
  end
end

