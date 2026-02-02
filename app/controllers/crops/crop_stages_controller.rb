# frozen_string_literal: true

module Crops
  class CropStagesController < Api::V1::BaseController
    include Views::Api::Crop::CropStageCreateView

    before_action :authenticate_user!
    before_action :find_crop
    before_action :find_crop_stage, only: [:show, :update, :destroy]

    def index
      input_dto = Domain::Crop::Dtos::CropStageListInputDto.new(crop_id: @crop.id)
      interactor.call(input_dto)
    end

    def show
      input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: @crop_stage.id)
      interactor.call(input_dto)
    end

    def create
      unless valid_create_params?
        return render(json: { error: 'Invalid parameters' }, status: :bad_request)
      end

      input_dto = Domain::Crop::Dtos::CropStageCreateInputDto.new(
        crop_id: @crop.id,
        payload: crop_stage_params
      )

      interactor.call(input_dto)
    end

    def update
      unless valid_update_params?
        return render(json: { error: 'Invalid parameters' }, status: :bad_request)
      end

      input_dto = Domain::Crop::Dtos::CropStageUpdateInputDto.new(
        crop_stage_id: @crop_stage.id,
        payload: crop_stage_params
      )

      interactor.call(input_dto)
    end

    def destroy
      input_dto = Domain::Crop::Dtos::CropStageDeleteInputDto.new(
        crop_stage_id: @crop_stage.id
      )

      interactor.call(input_dto)
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

    def find_crop
      @crop = Domain::Shared::Policies::CropPolicy.visible_scope(::Crop, current_user).where(is_reference: false).find(params[:crop_id])
    rescue ActiveRecord::RecordNotFound
      render(json: { error: 'Crop not found' }, status: :not_found)
    end

    def find_crop_stage
      @crop_stage = @crop.crop_stages.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render(json: { error: 'CropStage not found' }, status: :not_found)
    end

    def interactor
      @interactor ||= Domain::Crop::Interactors::CropStageCreateInteractor.new(
        output_port: presenter,
        gateway: gateway
      )
    end

    def presenter
      @presenter ||= Presenters::Api::Crop::CropStageCreatePresenter.new(view: self)
    end

    def gateway
      @gateway ||= Adapters::Crop::Gateways::CropMemoryGateway.new
    end
  end
end