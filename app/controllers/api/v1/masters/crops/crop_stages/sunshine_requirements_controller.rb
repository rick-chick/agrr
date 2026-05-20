# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          # 生育ステージと日照要件の関連管理API
          class SunshineRequirementsController < BaseController
            before_action :set_crop_and_crop_stage

            def show
              input_dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersSunshineRequirementShowInteractor.new(
                output_port: sunshine_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def create
              input_dto = Domain::Crop::Dtos::SunshineRequirementUpdateInput.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: sunshine_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersSunshineRequirementCreateInteractor.new(
                output_port: sunshine_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def update
              input_dto = Domain::Crop::Dtos::SunshineRequirementUpdateInput.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: sunshine_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersSunshineRequirementUpdateInteractor.new(
                output_port: sunshine_requirement_presenter,
                gateway: CompositionRoot.crop_gateway
              )
              interactor.call(input_dto)
            end

            def destroy
              input_dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersSunshineRequirementDestroyInteractor.new(
                output_port: sunshine_requirement_presenter,
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
              failure = Adapters::Crop::Presenters::Api::CropNestedRecordNotFoundJsonPresenter.new(view: self, error_message: "CropStage not found")
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

            def sunshine_requirement_params
              params.require(:sunshine_requirement).permit(:minimum_sunshine_hours, :target_sunshine_hours)
            end

            def sunshine_requirement_presenter
              @sunshine_requirement_presenter ||= Adapters::Crop::Presenters::Api::MastersSunshineRequirementPresenter.new(view: self)
            end
          end
        end
      end
    end
  end
end
