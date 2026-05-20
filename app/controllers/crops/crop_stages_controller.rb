# frozen_string_literal: true

module Crops
  class CropStagesController < Api::V1::BaseController

    before_action :authenticate_user!
    before_action :find_crop_for_list_and_create, only: [ :index, :create ]
    before_action :find_crop_and_crop_stage, only: [ :show, :update, :destroy ]

    def index
      input_dto = Domain::Crop::Dtos::CropStageListInput.new(crop_id: @crop.id)
      list_interactor.call(input_dto)
    end

    def show
      input_dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: @crop_stage.id)
      detail_interactor.call(input_dto)
    end

    def create
      unless valid_create_params?
        return render(json: { error: "Invalid parameters" }, status: :bad_request)
      end

      input_dto = Domain::Crop::Dtos::CropStageCreateInput.new(
        crop_id: @crop.id,
        payload: crop_stage_params
      )

      interactor.call(input_dto)
    end

    def update
      unless valid_update_params?
        return render(json: { error: "Invalid parameters" }, status: :bad_request)
      end

      input_dto = Domain::Crop::Dtos::CropStageUpdateInput.new(
        crop_stage_id: @crop_stage.id,
        payload: crop_stage_params
      )

      update_interactor.call(input_dto)
    end

    def destroy
      input_dto = Domain::Crop::Dtos::CropStageDeleteInput.new(
        crop_stage_id: @crop_stage.id
      )

      destroy_interactor.call(input_dto)
    end

    def render_response(json:, status:)
      render(json: json, status: status)
    end

    private

    def valid_create_params?
      params[:crop_stage].present? && params[:crop_stage][:name].present? && params[:crop_stage][:order].present?
    end

    def valid_update_params?
      params[:crop_stage].present? && (params[:crop_stage][:name].present? || params[:crop_stage][:order].present?)
    end

    def crop_stage_params
      params.require(:crop_stage).permit(:name, :order)
    end

    def find_crop_for_list_and_create
      presenter = Adapters::Crop::Presenters::Api::CropLoadForMastersPresenter.new(view: self)
      interactor = Domain::Crop::Interactors::CropLoadUserNonReferenceForMastersInteractor.new(output_port: presenter,
        user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
      interactor.call(params[:crop_id])
    end

    def find_crop_and_crop_stage
      failure = Adapters::Crop::Presenters::Api::CropNestedRecordNotFoundJsonPresenter.new(view: self, error_message: "CropStage not found")
      interactor = Domain::Crop::Interactors::CropLoadMastersAuthorizedCropStageInteractor.new(
        failure_presenter: failure,
        user_id: current_user.id,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      bundle = interactor.call(params[:crop_id], params[:id])
      return if bundle.nil?

      @crop = bundle.crop_entity
      @crop_stage = bundle.crop_stage_entity
    end

    def interactor
      @interactor ||= Domain::Crop::Interactors::CropStageCreateInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway)
    end

    def list_interactor
      @list_interactor ||= Domain::Crop::Interactors::CropStageListInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway)
    end

    def detail_interactor
      @detail_interactor ||= Domain::Crop::Interactors::CropStageDetailInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway)
    end

    def update_interactor
      @update_interactor ||= Domain::Crop::Interactors::CropStageUpdateInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway)
    end

    def destroy_interactor
      @destroy_interactor ||= Domain::Crop::Interactors::CropStageDeleteInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway)
    end

    def presenter
      @presenter ||= Adapters::Crop::Presenters::Api::CropStageCreatePresenter.new(view: self)
    end

  end
end
