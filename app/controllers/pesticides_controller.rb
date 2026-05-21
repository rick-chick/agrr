# frozen_string_literal: true

class PesticidesController < ApplicationController
  before_action :load_pesticide_for_view, only: [ :edit, :update ]

  # GET /pesticides
  def index
    presenter = Adapters::Pesticide::Presenters::PesticideListHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup).call
  end

  # GET /pesticides/:id
  def show
    presenter = Adapters::Pesticide::Presenters::PesticideDetailHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  # GET /pesticides/new
  def new
    @pesticide = CompositionRoot.pesticide_gateway.build_new_pesticide_with_attributes_for_master_form(attributes: {})
    load_crops_and_pests
  end

  # GET /pesticides/:id/edit
  def edit
    load_crops_and_pests
  end

  # POST /pesticides
  def create
    input_dto = Domain::Pesticide::Dtos::PesticideCreateInput.from_hash(pesticide_params.to_unsafe_h.deep_symbolize_keys)
    presenter = Adapters::Pesticide::Presenters::PesticideCreateHtmlPresenter.new(view: self)

    Domain::Pesticide::Interactors::PesticideCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # PATCH/PUT /pesticides/:id
  def update
    input_dto = Domain::Pesticide::Dtos::PesticideUpdateInput.from_hash(pesticide_params.to_unsafe_h.deep_symbolize_keys, params[:id])
    presenter = Adapters::Pesticide::Presenters::PesticideUpdateHtmlPresenter.new(view: self)

    Domain::Pesticide::Interactors::PesticideUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # DELETE /pesticides/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Adapters::Pesticide::Presenters::PesticideDestroyHtmlPresenter.new(view: self)
        Domain::Pesticide::Interactors::PesticideDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
      end

      format.json do
        Adapters::DeletionUndo::HtmlMasterScheduleInvoker.call(
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

  # Presenter から失敗時に呼び出される（Crop パターン準拠）
  def after_pesticide_create_failure
    @pesticide = CompositionRoot.pesticide_gateway.build_new_pesticide_with_attributes_for_master_form(
      attributes: pesticide_params.to_unsafe_h.deep_symbolize_keys
    )
    load_crops_and_pests
  end

  # Presenter から失敗時に呼び出される（Crop パターン準拠）
  def after_pesticide_update_failure
    user = CompositionRoot.user_lookup.find(current_user.id)
    access_filter = Domain::Shared::Policies::PesticidePolicy.record_access_filter(user)
    @pesticide = CompositionRoot.pesticide_gateway.merge_edit_pesticide_params_for_master_form!(
      user: user,
      pesticide_id: params[:id].to_i,
      attributes: pesticide_params.to_unsafe_h.deep_symbolize_keys,
      access_filter: access_filter
    )
    load_crops_and_pests
  end

  private

  def load_pesticide_for_view
    presenter = Adapters::Pesticide::Presenters::PesticideLoadForViewHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideLoadAuthorizedModelForViewInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  def load_crops_and_pests
    gw = CompositionRoot.pesticide_gateway
    @crops = gw.accessible_crops_scope_for_pesticide_master_form(user: current_user)
    @pests = gw.accessible_pests_scope_for_pesticide_master_form(user: current_user)
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
