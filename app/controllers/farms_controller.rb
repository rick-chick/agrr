# frozen_string_literal: true

class FarmsController < ApplicationController
  # GET /farms
  def index
    input_dto = Domain::Farm::Dtos::FarmListInput.new(is_admin: admin_user?)
    presenter = Adapters::Farm::Presenters::FarmListHtmlPresenter.new(view: self)

    Domain::Farm::Interactors::FarmListRowsBundleInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: CompositionRoot.farm_gateway
    ).call(input_dto)
  end

  # GET /farms/:id
  def show
    presenter = Adapters::Farm::Presenters::FarmDetailHtmlPresenter.new(view: self)

    interactor = Domain::Farm::Interactors::FarmDetailInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call(params[:id])
  end

  # POST /farms
  def create
    @input_dto = Domain::Farm::Dtos::FarmCreateInput.from_hash({ farm: farm_params.to_h.symbolize_keys })
    presenter = Adapters::Farm::Presenters::FarmCreateHtmlPresenter.new(view: self)

    interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # PATCH/PUT /farms/:id
  def update
    @input_dto = Domain::Farm::Dtos::FarmUpdateInput.from_hash({ farm: farm_params.to_h.symbolize_keys }, params[:id])
    presenter = Adapters::Farm::Presenters::FarmUpdateHtmlPresenter.new(view: self)

    interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # DELETE /farms/:id
  def destroy
    presenter = Adapters::Farm::Presenters::FarmDestroyHtmlPresenter.new(view: self)

    interactor = Domain::Farm::Interactors::FarmDestroyInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call(params[:id])
  end

  # View interface for HTML Presenters（Presenter から呼ばれるため public）
  def redirect_to(path, notice: nil, alert: nil)
    super(path, notice: notice, alert: alert)
  end

  def farm_path(farm)
    Rails.application.routes.url_helpers.farm_path(farm)
  end

  def farms_path
    Rails.application.routes.url_helpers.farms_path
  end

  private

  def farm_params
    params.require(:farm).permit(:name, :latitude, :longitude, :region, :is_reference)
  end
end
