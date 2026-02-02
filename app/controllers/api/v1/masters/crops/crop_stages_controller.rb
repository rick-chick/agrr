# frozen_string_literal: true

module Api::V1::Masters::Crops
  class CropStagesController < Api::V1::Masters::BaseController
    include Views::Api::Crop::CropStageListView
    include Views::Api::Crop::CropStageDetailView
    include Views::Api::Crop::CropStageCreateView
    include Views::Api::Crop::CropStageUpdateView
    include Views::Api::Crop::CropStageDeleteView

    rescue_from Domain::Shared::Policies::PolicyPermissionDenied do
      render(json: { error: 'Crop not found' }, status: :not_found)
    end

    before_action :find_visible_crop, only: [:index, :show]
    before_action :find_editable_crop, only: [:create, :update, :destroy]
    before_action :find_crop_stage, only: [:show, :update, :destroy]

    def index
      input_dto = Domain::Crop::Dtos::CropStageListInputDto.new(crop_id: @crop.id)

      interactor = Domain::Crop::Interactors::CropStageListInteractor.new(
        output_port: list_presenter,
        gateway: gateway
      )
      interactor.call(input_dto)
    end

    def show
      input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: @crop_stage.id)

      interactor = Domain::Crop::Interactors::CropStageDetailInteractor.new(
        output_port: detail_presenter,
        gateway: gateway
      )
      interactor.call(input_dto)
    end

    def create
      unless valid_create_params?
        return render(json: { error: 'Invalid parameters' }, status: :bad_request)
      end

      input_dto = Domain::Crop::Dtos::CropStageCreateInputDto.new(
        crop_id: @crop.id,
        payload: crop_stage_params.to_h
      )

      interactor = Domain::Crop::Interactors::CropStageCreateInteractor.new(
        output_port: create_presenter,
        gateway: gateway
      )
      interactor.call(input_dto)
    end

    def update
      unless valid_update_params?
        return render(json: { error: 'Invalid parameters' }, status: :bad_request)
      end

      input_dto = Domain::Crop::Dtos::CropStageUpdateInputDto.new(
        crop_id: @crop.id,
        stage_id: @crop_stage.id,
        payload: crop_stage_params.to_h
      )

      interactor = Domain::Crop::Interactors::CropStageUpdateInteractor.new(
        output_port: update_presenter,
        gateway: gateway
      )
      interactor.call(input_dto)
    end

    def destroy
      input_dto = Domain::Crop::Dtos::CropStageDeleteInputDto.new(
        crop_id: @crop.id,
        stage_id: @crop_stage.id
      )

      interactor = Domain::Crop::Interactors::CropStageDeleteInteractor.new(
        output_port: delete_presenter,
        gateway: gateway
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
      return false unless params[:crop_stage].present?

      name = params[:crop_stage][:name]
      order = params[:crop_stage][:order]

      return false if params[:crop_stage].key?(:name) && name.blank?
      return false if params[:crop_stage].key?(:order) && order.blank?

      name.present? || order.present?
    end

    def crop_stage_params
      params.require(:crop_stage).permit(:name, :order)
    end

    def find_visible_crop
      @crop = Domain::Shared::Policies::CropPolicy.find_visible!(::Crop, current_user, params[:crop_id])
    rescue ActiveRecord::RecordNotFound
      render(json: { error: 'Crop not found' }, status: :not_found)
    end

    def find_editable_crop
      @crop = Domain::Shared::Policies::CropPolicy.find_editable!(::Crop, current_user, params[:crop_id])
    rescue ActiveRecord::RecordNotFound
      render(json: { error: 'Crop not found' }, status: :not_found)
    end

    def find_crop_stage
      @crop_stage = @crop.crop_stages.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render(json: { error: 'CropStage not found' }, status: :not_found)
    end

    def list_presenter
      @list_presenter ||= Presenters::Api::Crop::CropStageListPresenter.new(view: self)
    end

    def detail_presenter
      @detail_presenter ||= Presenters::Api::Crop::CropStageDetailPresenter.new(view: self)
    end

    def create_presenter
      @create_presenter ||= Presenters::Api::Crop::CropStageCreatePresenter.new(view: self)
    end

    def update_presenter
      @update_presenter ||= Presenters::Api::Crop::CropStageUpdatePresenter.new(view: self)
    end

    def delete_presenter
      @delete_presenter ||= Presenters::Api::Crop::CropStageDeletePresenter.new(view: self)
    end

    def gateway
      @gateway ||= Adapters::Crop::Gateways::CropMemoryGateway.new
    end
  end
end