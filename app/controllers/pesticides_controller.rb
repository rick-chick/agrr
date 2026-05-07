# frozen_string_literal: true

class PesticidesController < ApplicationController
  before_action :load_pesticide_for_view, only: [ :edit, :update ]

  # GET /pesticides
  def index
    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call
  end

  # GET /pesticides/:id
  def show
    presenter = Presenters::Html::Pesticide::PesticideDetailHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  # GET /pesticides/new
  def new
    @pesticide = CompositionRoot.pesticide_gateway.build_blank_pesticide_for_html_form
    load_crops_and_pests
  end

  # GET /pesticides/:id/edit
  def edit
    CompositionRoot.pesticide_gateway.ensure_nested_associations_for_pesticide_html_form!(@pesticide)
    load_crops_and_pests
  end

  # POST /pesticides
  def create
    input_dto = Domain::Pesticide::Dtos::PesticideCreateInputDto.from_hash(pesticide_params.to_unsafe_h.deep_symbolize_keys)
    presenter = Presenters::Html::Pesticide::PesticideCreateHtmlPresenter.new(view: self)

    # 失敗時にフォーム再表示するために @pesticide をセット
    @pesticide = CompositionRoot.pesticide_gateway.build_pesticide_for_create_failure_html_form(
      pesticide_params.to_unsafe_h.deep_symbolize_keys
    )

    Domain::Pesticide::Interactors::PesticideCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, translator: translator, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # PATCH/PUT /pesticides/:id
  def update
    input_dto = Domain::Pesticide::Dtos::PesticideUpdateInputDto.from_hash(pesticide_params.to_unsafe_h.deep_symbolize_keys, params[:id])
    presenter = Presenters::Html::Pesticide::PesticideUpdateHtmlPresenter.new(view: self)

    # 失敗時にフォーム再表示するために @pesticide を更新
    CompositionRoot.pesticide_gateway.assign_pesticide_attributes_for_html_form!(
      @pesticide,
      pesticide_params.to_unsafe_h.deep_symbolize_keys
    )

    Domain::Pesticide::Interactors::PesticideUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, translator: translator, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # DELETE /pesticides/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Pesticide::PesticideDestroyHtmlPresenter.new(view: self)
        Domain::Pesticide::Interactors::PesticideDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.pesticide_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(params[:id])
      end

      format.json do
        DeletionUndo::HtmlMasterScheduleInvoker.call(
          view: self,
          actor_id: current_user.id,
          resource_type: "Pesticide",
          resource_id: params[:id].to_i,
          toast_message: nil,
          fallback_location: pesticides_path,
          in_use_message_key: nil,
          delete_error_message_key: "pesticides.flash.delete_error"
        )
      end
    end
  end

  # View interface for HTML Presenters（Presenter から呼ばれるため public）
  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

  private

  def load_pesticide_for_view
    presenter = Presenters::Html::Pesticide::PesticideLoadForViewHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideLoadAuthorizedModelForViewInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  def load_crops_and_pests
    gw = CompositionRoot.pesticide_gateway
    @crops = gw.accessible_crops_scope_for_pesticide_html_form(user: current_user)
    @pests = gw.accessible_pests_scope_for_pesticide_html_form(user: current_user)
  end

  def pesticide_params
    permitted = [
      :name,
      :active_ingredient,
      :description,
      :crop_id,
      :pest_id,
      :is_reference,
      pesticide_usage_constraint_attributes: [
        :id,
        :min_temperature,
        :max_temperature,
        :max_wind_speed_m_s,
        :max_application_count,
        :harvest_interval_days,
        :other_constraints,
        :_destroy
      ],
      pesticide_application_detail_attributes: [
        :id,
        :dilution_ratio,
        :amount_per_m2,
        :amount_unit,
        :application_method,
        :_destroy
      ]
    ]

    # 管理者のみregionを許可
    permitted << :region if admin_user?

    params.require(:pesticide).permit(*permitted)
  end
end
