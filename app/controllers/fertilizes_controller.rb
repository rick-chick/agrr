# frozen_string_literal: true

class FertilizesController < ApplicationController
  before_action :set_fertilize, only: [ :edit, :update ]

  # GET /fertilizes
  def index
    presenter = Adapters::Fertilize::Presenters::FertilizeListHtmlPresenter.new(view: self)
    interactor = Domain::Fertilize::Interactors::FertilizeListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.fertilize_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call
  end

  # GET /fertilizes/:id
  def show
    presenter = Adapters::Fertilize::Presenters::FertilizeDetailHtmlPresenter.new(view: self)
    interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.fertilize_gateway, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:id])
  end

  # GET /fertilizes/new
  def new
    presenter = Adapters::Fertilize::Presenters::FertilizeNewMasterFormHtmlPresenter.new(view: self)
    Domain::Fertilize::Interactors::FertilizeNewMasterFormInteractor.new(output_port: presenter,
      gateway: CompositionRoot.fertilize_gateway).call
  end

  # GET /fertilizes/:id/edit
  def edit
  end

  # POST /fertilizes
  def create
    input_dto = Domain::Fertilize::Dtos::FertilizeCreateInput.from_hash({ fertilize: fertilize_params.to_h.symbolize_keys })
    presenter = Adapters::Fertilize::Presenters::FertilizeCreateHtmlPresenter.new(view: self)
    Domain::Fertilize::Interactors::FertilizeCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.fertilize_gateway, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # PATCH/PUT /fertilizes/:id
  def update
    input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInput.from_hash({ fertilize: fertilize_params.to_h.symbolize_keys }, params[:id])
    presenter = Adapters::Fertilize::Presenters::FertilizeUpdateHtmlPresenter.new(view: self)
    Domain::Fertilize::Interactors::FertilizeUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.fertilize_gateway, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # DELETE /fertilizes/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Adapters::Fertilize::Presenters::FertilizeDestroyHtmlPresenter.new(view: self)
        Domain::Fertilize::Interactors::FertilizeDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.fertilize_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
      end

      format.json do
        Adapters::DeletionUndo::HtmlMasterScheduleInvoker.call(
          view: self,
          actor_id: current_user.id,
          resource_type: "Fertilize",
          resource_id: params[:id].to_i,
          toast_message: nil,
          fallback_location: fertilizes_path,
          in_use_message_key: nil,
          delete_error_message_key: "fertilizes.flash.delete_error"
        )
      end
    end
  end

  private

  def set_fertilize
    presenter = Adapters::Fertilize::Presenters::FertilizeLoadForViewHtmlPresenter.new(view: self)
    interactor = Domain::Fertilize::Interactors::FertilizeLoadAuthorizedModelForViewInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.fertilize_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:id])
  end

  def fertilize_params
    # region / is_reference は mass-assignment 許可のみ。admin 限定の認可は
    # FertilizePolicy.normalize_attrs_for_* と FertilizeCreate/UpdateInteractor が判定する。
    permitted = [
      :name,
      :n,
      :p,
      :k,
      :description,
      :package_size,
      :is_reference,
      :region
    ]

    params.require(:fertilize).permit(*permitted)
  end
end
