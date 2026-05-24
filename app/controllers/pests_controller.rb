# frozen_string_literal: true

class PestsController < ApplicationController
  # GET /pests
  def index
    presenter = Adapters::Pest::Presenters::PestListHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestListInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call
  end

  # GET /pests/:id
  def show
    presenter = Adapters::Pest::Presenters::PestDetailHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestDetailInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  # POST /pests
  def create
    input_dto = Domain::Pest::Dtos::PestCreateInput.from_hash(
      { pest: pest_params.to_h.symbolize_keys, crop_ids: params[:crop_ids] }
    )
    presenter = Adapters::Pest::Presenters::PestCreateHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestCreateInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # PATCH/PUT /pests/:id
  def update
    input_dto = Domain::Pest::Dtos::PestUpdateInput.from_hash(
      { pest: pest_params.to_h.symbolize_keys, crop_ids: params[:crop_ids] },
      params[:id]
    )
    presenter = Adapters::Pest::Presenters::PestUpdateHtmlPresenter.new(
      view: self
    )
    Domain::Pest::Interactors::PestUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # DELETE /pests/:id
  def destroy
    presenter = Adapters::Pest::Presenters::PestDestroyHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestDestroyInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  private

  def translator
    @translator ||= CompositionRoot.translator
  end

  def pest_params
    permitted = [
      :name,
      :name_scientific,
      :family,
      :order,
      :description,
      :occurrence_season,
      :is_reference,
      :region,
      pest_temperature_profile_attributes: [
        :id,
        :base_temperature,
        :max_temperature,
        :_destroy
      ],
      pest_thermal_requirement_attributes: [
        :id,
        :required_gdd,
        :first_generation_gdd,
        :_destroy
      ],
      pest_control_methods_attributes: [
        :id,
        :method_type,
        :method_name,
        :description,
        :timing_hint,
        :_destroy
      ]
    ]

    params.require(:pest).permit(*permitted)
  end
end
