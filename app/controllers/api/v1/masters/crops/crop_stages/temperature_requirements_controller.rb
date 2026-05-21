# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          # 生育ステージと温度要件の関連管理API
          #
          # @example 温度要件の取得
          #   GET /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement
          #   Headers: X-API-Key: <api_key>
          #
          # @note 認証: APIキー認証が必要です（X-API-KeyヘッダーまたはAuthorization: Bearer <api_key>）
          # @note 権限: ユーザーは自分の所有する作物のみアクセス可能です
          class TemperatureRequirementsController < BaseController
            before_action :set_crop_and_crop_stage

            def show
              input_dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersTemperatureRequirementShowInteractor.new(
                output_port: temperature_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def create
              input_dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: temperature_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersTemperatureRequirementCreateInteractor.new(
                output_port: temperature_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def update
              input_dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: temperature_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersTemperatureRequirementUpdateInteractor.new(
                output_port: temperature_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def destroy
              input_dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersTemperatureRequirementDestroyInteractor.new(
                output_port: temperature_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def render_response(json:, status:)
              render(json: json, status: status)
            end

            def render_no_content
              head :no_content
            end

            private

            def set_crop_and_crop_stage
              failure = Adapters::Crop::Presenters::CropNestedRecordNotFoundJsonApiPresenter.new(view: self, error_message: "CropStage not found")
              interactor = Domain::Crop::Interactors::CropLoadMastersAuthorizedCropStageInteractor.new(
                failure_presenter: failure,
                user_id: current_user.id,
                gateway: CompositionRoot.crop_gateway,
                user_lookup: CompositionRoot.user_lookup
              )
              bundle = interactor.call(params[:crop_id], params[:crop_stage_id])
              return if bundle.nil?

              @crop = bundle.crop_entity
              @crop_stage = bundle.crop_stage_entity
            end

            def temperature_requirement_params
              params.require(:temperature_requirement).permit(
                :base_temperature, :optimal_min, :optimal_max,
                :low_stress_threshold, :high_stress_threshold,
                :frost_threshold, :sterility_risk_threshold, :max_temperature
              )
            end

            def temperature_requirement_presenter
              @temperature_requirement_presenter ||= Adapters::Crop::Presenters::MastersTemperatureRequirementApiPresenter.new(view: self)
            end
          end
        end
      end
    end
  end
end
