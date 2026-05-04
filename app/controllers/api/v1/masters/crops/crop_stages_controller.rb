# frozen_string_literal: true

module Api::V1::Masters::Crops
  class CropStagesController < Api::V1::Masters::BaseController
    include Views::Api::Crop::CropStageListView
    include Views::Api::Crop::CropStageDetailView
    include Views::Api::Crop::CropStageCreateView
    include Views::Api::Crop::CropStageUpdateView
    include Views::Api::Crop::CropStageDeleteView

    before_action :find_visible_crop, only: [ :index, :show ]
    before_action :find_editable_crop, only: [ :create, :update, :destroy ]
    before_action :find_crop_stage, only: [ :show, :update, :destroy ]

    def index
      input_dto = Domain::Crop::Dtos::CropStageListInputDto.new(crop_id: @crop.id)

      interactor = Domain::Crop::Interactors::CropStageListInteractor.new(output_port: list_presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger)
      interactor.call(input_dto)
    end

    def show
      input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: @crop_stage.id)

      interactor = Domain::Crop::Interactors::CropStageDetailInteractor.new(output_port: detail_presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger)
      interactor.call(input_dto)
    end

    def create
      unless valid_create_params?
        return render(json: { error: "Invalid parameters" }, status: :bad_request)
      end

      input_dto = Domain::Crop::Dtos::CropStageCreateInputDto.new(
        crop_id: @crop.id,
        payload: crop_stage_params.to_h
      )

      interactor = Domain::Crop::Interactors::CropStageCreateInteractor.new(output_port: create_presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger)
      interactor.call(input_dto)
    end

    def update
      unless valid_update_params?
        return render(json: { error: "Invalid parameters" }, status: :bad_request)
      end

      input_dto = Domain::Crop::Dtos::CropStageUpdateInputDto.new(
        crop_id: @crop.id,
        stage_id: @crop_stage.id,
        payload: crop_stage_params.to_h
      )

      interactor = Domain::Crop::Interactors::CropStageUpdateInteractor.new(output_port: update_presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger)
      interactor.call(input_dto)
    end

    def destroy
      input_dto = Domain::Crop::Dtos::CropStageDeleteInputDto.new(
        crop_id: @crop.id,
        stage_id: @crop_stage.id
      )

      interactor = Domain::Crop::Interactors::CropStageDeleteInteractor.new(output_port: delete_presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger)
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
      load_authorized_parent_crop(for_edit: false)
    end

    def find_editable_crop
      load_authorized_parent_crop(for_edit: true)
    end

    def load_authorized_parent_crop(for_edit:)
      presenter = Presenters::Api::Crop::CropParentAuthorizationFailurePresenter.new(view: self)
      interactor = Domain::Crop::Interactors::CropLoadAuthorizedInteractor.new(failure_presenter: presenter,
        user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
      bundle = interactor.call(params[:crop_id], for_edit: for_edit)
      return if bundle.nil?

      @crop = bundle.persisted_crop
    end

    def find_crop_stage
      for_edit = %w[update destroy].include?(action_name)
      failure = Presenters::Api::Crop::CropNestedRecordNotFoundJsonPresenter.new(view: self, error_message: "CropStage not found")
      interactor = Domain::Crop::Interactors::CropLoadAuthorizedCropStageInteractor.new(
        failure_presenter: failure,
        user_id: current_user.id,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup,
        for_edit: for_edit
      )
      bundle = interactor.call(params[:crop_id], params[:id])
      return if bundle.nil?

      @crop_stage = bundle.persisted_crop_stage
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

  end
end
