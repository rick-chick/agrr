# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          # 生育ステージと積算温度要件の関連管理API
          class ThermalRequirementsController < BaseController
            before_action :set_crop_and_crop_stage

            def show
              input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersThermalRequirementShowInteractor.new(
                output_port: thermal_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def create
              input_dto = Domain::Crop::Dtos::ThermalRequirementUpdateInputDto.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: thermal_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersThermalRequirementCreateInteractor.new(
                output_port: thermal_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def update
              input_dto = Domain::Crop::Dtos::ThermalRequirementUpdateInputDto.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: thermal_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersThermalRequirementUpdateInteractor.new(
                output_port: thermal_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def destroy
              input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersThermalRequirementDestroyInteractor.new(
                output_port: thermal_requirement_presenter,
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
              failure = Presenters::Api::Crop::CropNestedRecordNotFoundJsonPresenter.new(view: self, error_message: "CropStage not found")
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

            def thermal_requirement_params
              params.require(:thermal_requirement).permit(:required_gdd)
            end

            def thermal_requirement_presenter
              @thermal_requirement_presenter ||= Presenters::Api::Crop::MastersThermalRequirementPresenter.new(view: self)
            end
          end
        end
      end
    end
  end
end
