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
    presenter = Adapters::Pesticide::Presenters::PesticideNewMasterFormHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideNewMasterFormInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup).call
  end

  # GET /pesticides/:id/edit
  def edit
    presenter = Adapters::Pesticide::Presenters::PesticideEditFormPickListsHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideEditFormPickListsInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup).call
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

  private

  def load_pesticide_for_view
    presenter = Adapters::Pesticide::Presenters::PesticideLoadForViewHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideLoadAuthorizedModelForViewInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  def pesticide_params
    # region / is_reference は mass-assignment 許可のみ。admin 限定の認可は
    # PesticidePolicy.normalize_attrs_for_* と PesticideCreate/UpdateInteractor が判定する。
    permitted = [
      :name,
      :active_ingredient,
      :description,
      :crop_id,
      :pest_id,
      :is_reference,
      :region,
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

    params.require(:pesticide).permit(*permitted)
  end
end
