# frozen_string_literal: true

class InteractionRulesController < ApplicationController
  include DeletionUndoFlow
  before_action :preload_interaction_rule_entity, only: [ :show, :edit, :update ]
  before_action :load_interaction_rule_record, only: [ :destroy ]

  # GET /interaction_rules
  def index
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: self)
    Domain::InteractionRule::Interactors::InteractionRuleListInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      logger: logger_adapter,
      user_lookup: user_lookup_adapter
    ).call
  end

  # GET /interaction_rules/:id
  def show
    presenter = Presenters::Html::InteractionRule::InteractionRuleDetailHtmlPresenter.new(view: self)
    Domain::InteractionRule::Interactors::InteractionRuleDetailInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      logger: logger_adapter,
      user_lookup: user_lookup_adapter
    ).call(params[:id])
  end

  # GET /interaction_rules/new
  def new
    @form = InteractionRuleForm.new
  end

  # GET /interaction_rules/:id/edit
  def edit
    # @form は preload_interaction_rule_entity → Presenter で設定済み
  end

  # POST /interaction_rules
  def create
    filtered_params = interaction_rule_params.to_unsafe_h.symbolize_keys
    filtered_params.delete(:region) unless admin_user?

    @form = InteractionRuleForm.from_params(filtered_params)

    is_reference = ActiveModel::Type::Boolean.new.cast(filtered_params[:is_reference]) || false
    if is_reference && !admin_user?
      return redirect_to interaction_rules_path, alert: I18n.t("interaction_rules.flash.reference_only_admin")
    end

    presenter = Presenters::Html::InteractionRule::InteractionRuleCreateHtmlPresenter.new(view: self)
    interactor = Domain::InteractionRule::Interactors::InteractionRuleCreateInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      logger: logger_adapter,
      user_lookup: user_lookup_adapter
    )

    input_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInputDto.from_hash(
      filtered_params.merge(user_id: current_user.id)
    )
    interactor.call(input_dto)
  rescue StandardError => e
    @form ||= InteractionRuleForm.new
    @form.errors_from(base: e.message)
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  # PATCH/PUT /interaction_rules/:id
  def update
    if interaction_rule_params.key?(:is_reference) && !admin_user?
      return redirect_to interaction_rule_path(params[:id]), alert: I18n.t("interaction_rules.flash.reference_flag_admin_only")
    end

    filtered_params = interaction_rule_params.to_unsafe_h.symbolize_keys
    filtered_params.delete(:region) unless admin_user?

    @form = InteractionRuleForm.from_params(filtered_params.merge(id: params[:id].to_i))

    presenter = Presenters::Html::InteractionRule::InteractionRuleUpdateHtmlPresenter.new(view: self)
    interactor = Domain::InteractionRule::Interactors::InteractionRuleUpdateInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      logger: logger_adapter,
      user_lookup: user_lookup_adapter
    )

    input_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInputDto.from_hash(
      filtered_params,
      params[:id]
    )
    interactor.call(input_dto)
  rescue StandardError => e
    @form ||= InteractionRuleForm.from_params(interaction_rule_params.to_unsafe_h.merge(id: params[:id].to_i))
    @form.errors_from(base: e.message)
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  # DELETE /interaction_rules/:id
  def destroy
    rule = @interaction_rule_record
    toast_message = t("interaction_rules.undo.toast", source: rule.source_group, target: rule.target_group)
    schedule_deletion_with_undo(
      record: rule,
      toast_message: toast_message,
      fallback_location: interaction_rules_path,
      delete_error_message_key: "interaction_rules.flash.destroy_error"
    )
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to interaction_rules_path, alert: I18n.t("interaction_rules.flash.not_found")
  rescue StandardError => e
    if request.format.json?
      render json: { error: e.message }, status: :unprocessable_entity
    else
      redirect_to interaction_rules_path, alert: e.message
    end
  end

  private

  # ドメイン Gateway adapter (Composition Root として Controller で生成)
  def interaction_rule_gateway
    @interaction_rule_gateway ||= Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway
    )
  end

  def preload_interaction_rule_entity
    for_edit = params[:action].to_sym.in?([ :edit, :update ])
    presenter = Presenters::Html::InteractionRule::InteractionRuleHtmlLoadPresenter.new(view: self, for_edit: for_edit)
    Domain::InteractionRule::Interactors::InteractionRuleLoadInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      user_lookup: user_lookup_adapter
    ).call(rule_id: params[:id], for_edit: for_edit)
  end

  # destroy 用に AR レコードを取得する。
  # `schedule_deletion_with_undo` は ActiveRecord のレコードを必要とするため、
  # この経路だけは Adapter Gateway 経由で AR を直接取得する。
  def load_interaction_rule_record
    @interaction_rule_record = interaction_rule_gateway.find_authorized_model_for_edit(current_user, params[:id])
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to interaction_rules_path, alert: I18n.t("interaction_rules.flash.not_found")
  rescue Domain::Shared::Exceptions::RecordNotFound
    redirect_to interaction_rules_path, alert: I18n.t("interaction_rules.flash.not_found")
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
