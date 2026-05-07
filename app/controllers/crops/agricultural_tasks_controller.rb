# frozen_string_literal: true

module Crops
  class AgriculturalTasksController < ApplicationController
    before_action :authenticate_user!
    before_action :set_crop
    before_action :set_template, only: [ :edit, :update, :destroy ]

    # GET /crops/:crop_id/agricultural_tasks
    def index
      input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateIndexInputDto.new(
        user_id: current_user.id,
        crop_id: params[:crop_id]
      )
      presenter = Presenters::Html::Crop::CropMastersTaskTemplateIndexHtmlPresenter.new(view: self)
      interactor = Domain::Crop::Interactors::CropMastersTaskTemplateIndexInteractor.new(
        output_port: presenter,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      interactor.call(input_dto)
    end

    # GET /crops/:crop_id/agricultural_tasks/new
    def new
      input_dto = Domain::Crop::Dtos::CropNestedCropTaskTemplatesNewInputDto.new(
        user_id: current_user.id,
        crop_id: params[:crop_id]
      )
      presenter = Presenters::Html::Crop::CropNestedCropTaskTemplatesNewHtmlPresenter.new(view: self)
      interactor = Domain::Crop::Interactors::CropNestedCropTaskTemplatesNewInteractor.new(
        output_port: presenter,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      interactor.call(input_dto)
    end

    def edit
    end

    # POST /crops/:crop_id/agricultural_tasks
    def create
      if params[:agricultural_task_id].blank?
        redirect_to new_agricultural_task_path, notice: I18n.t("crops.agricultural_tasks.flash.redirect_to_create")
        return
      end

      input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInputDto.new(
        user_id: current_user.id,
        crop_id: params[:crop_id],
        agricultural_task_id: params[:agricultural_task_id],
        name: nil,
        description: nil,
        time_per_sqm: nil,
        weather_dependency: nil,
        required_tools: nil,
        skill_level: nil
      )
      presenter = Presenters::Html::Crop::CropMastersTaskTemplateCreateHtmlPresenter.new(view: self)
      interactor = Domain::Crop::Interactors::CropMastersTaskTemplateCreateInteractor.new(
        output_port: presenter,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      interactor.call(input_dto)
    end

    def update
      input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateUpdateInputDto.new(
        user_id: current_user.id,
        crop_id: params[:crop_id],
        template_id: params[:id],
        attributes: crop_task_template_update_attributes
      )
      presenter = Presenters::Html::Crop::CropMastersTaskTemplateUpdateHtmlPresenter.new(view: self)
      interactor = Domain::Crop::Interactors::CropMastersTaskTemplateUpdateInteractor.new(
        output_port: presenter,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      interactor.call(input_dto)
    end

    def destroy
      input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateDestroyInputDto.new(
        user_id: current_user.id,
        crop_id: params[:crop_id],
        template_id: params[:id]
      )
      presenter = Presenters::Html::Crop::CropMastersTaskTemplateDestroyHtmlPresenter.new(view: self)
      interactor = Domain::Crop::Interactors::CropMastersTaskTemplateDestroyInteractor.new(
        output_port: presenter,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      interactor.call(input_dto)
    end

    private

    def set_crop
      failure = Presenters::Html::Crop::CropAuthorizationFailureRedirectPresenter.new(view: self, permission_message_key: "crops.flash.no_permission")
      interactor = Domain::Crop::Interactors::CropLoadAuthorizedInteractor.new(
        failure_presenter: failure,
        user_id: current_user.id,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      bundle = interactor.call(params[:crop_id], for_edit: false)
      return if bundle.nil?

      @crop = bundle.persisted_crop
    end

    def set_template
      failure = Presenters::Html::Crop::CropTaskTemplateLoadFailureRedirectPresenter.new(view: self)
      interactor = Domain::Crop::Interactors::CropLoadAuthorizedCropTaskTemplateInteractor.new(
        failure_presenter: failure,
        user_id: current_user.id,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup,
        for_edit: true
      )
      bundle = interactor.call(@crop.id, params[:id])
      return if bundle.nil?

      @template = bundle.persisted_crop_task_template
    end

    def crop_task_template_update_attributes
      permitted = params.require(:crop_task_template).permit(
        :name,
        :description,
        :time_per_sqm,
        :weather_dependency,
        :skill_level,
        :required_tools
      ).to_h
      permitted[:required_tools] = normalize_required_tools(permitted[:required_tools])
      permitted
    end

    def normalize_required_tools(value)
      case value
      when Array
        value.map(&:to_s).map(&:strip).reject(&:blank?)
      when String
        value.split(/\r?\n|,/).map(&:strip).reject(&:blank?)
      else
        []
      end
    end
  end
end
