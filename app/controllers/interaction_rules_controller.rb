# frozen_string_literal: true

class InteractionRulesController < ApplicationController
  before_action :preload_interaction_rule_entity, only: [ :show, :edit, :update ]

  # GET /interaction_rules
  def index
    presenter = Adapters::InteractionRule::Presenters::InteractionRuleListHtmlPresenter.new(view: self)
    Domain::InteractionRule::Interactors::InteractionRuleListInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      user_lookup: user_lookup_adapter
    ).call
  end

  # GET /interaction_rules/:id
  def show
    presenter = Adapters::InteractionRule::Presenters::InteractionRuleDetailHtmlPresenter.new(view: self)
    Domain::InteractionRule::Interactors::InteractionRuleDetailInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      user_lookup: user_lookup_adapter
    ).call(params[:id])
  end

  # GET /interaction_rules/new
  def new
    @form = Adapters::InteractionRule::Presenters::Forms::InteractionRuleForm.new
  end

  # GET /interaction_rules/:id/edit
  def edit
    # @form は preload_interaction_rule_entity → Presenter で設定済み
  end

  # POST /interaction_rules
  def create
    # region / is_reference の認可（admin 限定）は InteractionRulePolicy・
    # InteractionRuleCreateInteractor が担う。Controller では認可判定を行わない。
    filtered_params = interaction_rule_params.to_unsafe_h.symbolize_keys

    @form = Adapters::InteractionRule::Presenters::Forms::InteractionRuleForm.from_params(filtered_params)

    presenter = Adapters::InteractionRule::Presenters::InteractionRuleCreateHtmlPresenter.new(view: self)
    interactor = Domain::InteractionRule::Interactors::InteractionRuleCreateInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      translator: translator,
      user_lookup: user_lookup_adapter
    )

    input_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInput.from_hash(
      filtered_params.merge(user_id: current_user.id)
    )
    interactor.call(input_dto)
  end

  # PATCH/PUT /interaction_rules/:id
  def update
    # region / is_reference の認可（admin 限定）は InteractionRulePolicy・
    # InteractionRuleUpdateInteractor が担う。Controller では認可判定を行わない。
    filtered_params = interaction_rule_params.to_unsafe_h.symbolize_keys

    @form = Adapters::InteractionRule::Presenters::Forms::InteractionRuleForm.from_params(filtered_params.merge(id: params[:id].to_i))

    presenter = Adapters::InteractionRule::Presenters::InteractionRuleUpdateHtmlPresenter.new(view: self)
    interactor = Domain::InteractionRule::Interactors::InteractionRuleUpdateInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      translator: translator,
      user_lookup: user_lookup_adapter
    )

    input_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInput.from_hash(
      filtered_params,
      params[:id]
    )
    interactor.call(input_dto)
  end

  # DELETE /interaction_rules/:id
  def destroy
    respond_to do |format|
      format.html do
        destroy_with_presenter(
          Adapters::InteractionRule::Presenters::InteractionRuleDestroyHtmlPresenter.new(view: self)
        )
      end
      format.json do
        destroy_with_presenter(
          Adapters::InteractionRule::Presenters::InteractionRuleDeleteApiPresenter.new(view: self)
        )
      end
    end
  end

  # JSON 削除応答: Presenter が controller を明示レシーバで呼ぶ
  def render_response(json:, status:)
    render json: json, status: status
  end

  def undo_deletion_path(undo_token:)
    Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
  end

  def interaction_rule_destroy_json_redirect_path
    interaction_rules_path
  end

  private

  # ドメイン Gateway adapter (Composition Root として Controller で生成)
  def interaction_rule_gateway
    @interaction_rule_gateway ||= Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
      translator: CompositionRoot.translator
    )
  end

  def preload_interaction_rule_entity
    for_edit = params[:action].to_sym.in?([ :edit, :update ])
    presenter = Adapters::InteractionRule::Presenters::InteractionRuleLoadHtmlPresenter.new(view: self, for_edit: for_edit)
    Domain::InteractionRule::Interactors::InteractionRuleLoadInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      user_lookup: user_lookup_adapter
    ).call(rule_id: params[:id], for_edit: for_edit)
  end

  def destroy_with_presenter(presenter)
    Domain::InteractionRule::Interactors::InteractionRuleDestroyInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: interaction_rule_gateway,
      translator: translator,
      user_lookup: user_lookup_adapter
    ).call(params[:id])
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
      :region  # mass-assignment 許可のみ。admin 限定の認可は InteractionRulePolicy が判定する
    ]
    params.require(:interaction_rule).permit(*permitted)
  end
end
