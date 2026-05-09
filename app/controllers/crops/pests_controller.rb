# frozen_string_literal: true

module Crops
  class PestsController < ApplicationController
    before_action :load_authorized_crop
    before_action :load_nested_pest, only: [ :show, :edit, :update ]

    # GET /crops/:crop_id/pests
    def index
      presenter = Presenters::Html::Crop::CropPestsIndexHtmlPresenter.new(view: self)
      Domain::Pest::Interactors::CropsNestedPestsIndexInteractor.new(output_port: presenter,
        user_id: current_user.id, user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway).call(crop_id: @crop.id)
    end

    # GET /crops/:crop_id/pests/:id
    def show
    end

    # GET /crops/:crop_id/pests/new
    def new
      presenter = Presenters::Html::Crop::CropPestsNewHtmlPresenter.new(view: self)
      Domain::Pest::Interactors::CropsNestedPestsNewInteractor.new(output_port: presenter,
        user_id: current_user.id, user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway).call(@crop)
    end

    # GET /crops/:crop_id/pests/:id/edit
    def edit
    end

    # POST /crops/:crop_id/pests
    def create
      presenter = Presenters::Html::Crop::CropPestsCreateHtmlPresenter.new(view: self)
      pest_attrs =
        if params[:pest].present?
          pest_params.respond_to?(:to_unsafe_h) ? pest_params.to_unsafe_h : pest_params.to_h
        else
          {}
        end
      Domain::Pest::Interactors::CropsNestedPestsCreateInteractor.new(output_port: presenter,
        user_id: current_user.id, user_lookup: CompositionRoot.user_lookup, pest_gateway: CompositionRoot.pest_gateway).call(
        crop_id: @crop.id,
        link_pest_id: params[:pest_id],
        pest_attrs: pest_attrs
      )
    end

    # PATCH/PUT /crops/:crop_id/pests/:id
    def update
      presenter = Presenters::Html::Crop::CropPestsUpdateHtmlPresenter.new(view: self)
      pest_attrs =
        if params[:pest].present?
          pest_params.respond_to?(:to_unsafe_h) ? pest_params.to_unsafe_h : pest_params.to_h
        else
          {}
        end
      Domain::Pest::Interactors::CropsNestedPestsUpdateInteractor.new(
        output_port: presenter,
        pest_gateway: CompositionRoot.pest_gateway,
        user_id: current_user.id,
        user_lookup: CompositionRoot.user_lookup
      ).call(
        crop_id: @crop.id,
        pest_id: @pest.id,
        pest_attrs: pest_attrs
      )
    end

    private

    def load_authorized_crop
      presenter = Presenters::Html::Crop::CropPestsLoadCropHtmlPresenter.new(view: self)
      Domain::Crop::Interactors::CropLoadAuthorizedForCropPestsInteractor.new(output_port: presenter,
        user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:crop_id])
    end

    def load_nested_pest
      presenter = Presenters::Html::Crop::CropPestsLoadPestHtmlPresenter.new(view: self)
      Domain::Pest::Interactors::CropsNestedPestsLoadPestInteractor.new(
        output_port: presenter,
        user_id: current_user.id,
        user_lookup: CompositionRoot.user_lookup,
        pest_gateway: CompositionRoot.pest_gateway
      ).call(crop_id: @crop.id, pest_id: params[:id],
        for_edit_form: action_name == "edit")
    end

    def pest_params
      params.require(:pest).permit(
        :name,
        :name_scientific,
        :family,
        :order,
        :description,
        :occurrence_season,
        :is_reference,
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
      )
    end
  end
end
