# frozen_string_literal: true

class FertilizesController < ApplicationController
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
    presenter = Adapters::Fertilize::Presenters::FertilizeDestroyHtmlPresenter.new(view: self)
    Domain::Fertilize::Interactors::FertilizeDestroyInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.fertilize_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  private

  def fertilize_params
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
