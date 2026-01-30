# frozen_string_literal: true

class InteractionRulesController < ApplicationController
  include DeletionUndoFlow
  before_action :set_interaction_rule, only: [:show, :edit, :update, :destroy]

  # GET /interaction_rules
  def index
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: self)
    interactor = Domain::InteractionRule::Interactors::InteractionRuleListInteractor.new(
      output_port: presenter,
      gateway: interaction_rule_gateway,
      user_id: current_user.id
    )
    interactor.call
  end

  # GET /interaction_rules/:id
  def show
    presenter = Presenters::Html::InteractionRule::InteractionRuleDetailHtmlPresenter.new(view: self)
    interactor = Domain::InteractionRule::Interactors::InteractionRuleDetailInteractor.new(
      output_port: presenter,
      gateway: interaction_rule_gateway
    )
    interactor.call(Domain::InteractionRule::Dtos::InteractionRuleDetailInputDto.new(
      rule_id: params[:id],
      user_id: current_user.id
    ))
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
    # 一般ユーザーの場合はregionパラメータを除外
    filtered_params = interaction_rule_params.to_unsafe_h
    filtered_params.delete(:region) unless admin_user?

    @interaction_rule = InteractionRule.new(filtered_params.symbolize_keys)

    is_reference = filtered_params[:is_reference] || false
    if is_reference && !admin_user?
      return redirect_to interaction_rules_path, alert: I18n.t('interaction_rules.flash.reference_only_admin')
    end

    presenter = Presenters::Html::InteractionRule::InteractionRuleCreateHtmlPresenter.new(view: self)
    interactor = Domain::InteractionRule::Interactors::InteractionRuleCreateInteractor.new(
      output_port: presenter,
      gateway: interaction_rule_gateway,
      user_id: current_user.id
    )

    input_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInputDto.from_hash(
      filtered_params.deep_symbolize_keys.merge(user_id: current_user.id)
    )
    interactor.call(input_dto)
  rescue StandardError => e
    @interaction_rule.assign_attributes(filtered_params.symbolize_keys) if @interaction_rule
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  # PATCH/PUT /interaction_rules/:id
  def update
    if interaction_rule_params.key?(:is_reference) && !admin_user?
      return redirect_to @interaction_rule, alert: I18n.t('interaction_rules.flash.reference_flag_admin_only')
    end

    # 一般ユーザーの場合はregionパラメータを除外
    filtered_params = interaction_rule_params.to_unsafe_h
    filtered_params.delete(:region) unless admin_user?

    presenter = Presenters::Html::InteractionRule::InteractionRuleUpdateHtmlPresenter.new(view: self)
    interactor = Domain::InteractionRule::Interactors::InteractionRuleUpdateInteractor.new(
      output_port: presenter,
      gateway: interaction_rule_gateway,
      user_id: current_user.id
    )

    input_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInputDto.from_hash(
      filtered_params.deep_symbolize_keys.merge(user_id: current_user.id),
      params[:id]
    )
    interactor.call(input_dto)
  rescue StandardError => e
    @interaction_rule.assign_attributes(interaction_rule_params) if @interaction_rule
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  # DELETE /interaction_rules/:id
  def destroy
    rule = Domain::Shared::Policies::InteractionRulePolicy.find_editable!(::InteractionRule, current_user, params[:id])
    toast_message = t('interaction_rules.undo.toast', source: rule.source_group, target: rule.target_group)
    schedule_deletion_with_undo(
      record: rule,
      toast_message: toast_message,
      fallback_location: interaction_rules_path,
      delete_error_message_key: 'interaction_rules.flash.destroy_error'
    )
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to interaction_rules_path, alert: I18n.t('interaction_rules.flash.not_found')
  rescue StandardError => e
    if request.format.json?
      render json: { error: e.message }, status: :unprocessable_entity
    else
      redirect_to interaction_rules_path, alert: e.message
    end
  end

  private

  def interaction_rule_gateway
    @interaction_rule_gateway ||= Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new
  end

  def set_interaction_rule
    action = params[:action].to_sym

    @interaction_rule =
      if action.in?([:edit, :update, :destroy])
        Domain::Shared::Policies::InteractionRulePolicy.find_editable!(InteractionRule, current_user, params[:id])
      else
        Domain::Shared::Policies::InteractionRulePolicy.find_visible!(InteractionRule, current_user, params[:id])
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
      :is_reference,
      :region  # regionパラメータは常に許可（一般ユーザーの場合は無視される）
    ]

    params.require(:interaction_rule).permit(*permitted)
  end
end

