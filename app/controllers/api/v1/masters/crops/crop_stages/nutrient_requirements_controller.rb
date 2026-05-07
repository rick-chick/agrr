# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          # 生育ステージと栄養素要件の関連管理API
          class NutrientRequirementsController < BaseController
            before_action :set_crop_and_crop_stage

            def show
              input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersNutrientRequirementShowInteractor.new(
                output_port: nutrient_requirement_api_presenter,
                gateway: CompositionRoot.crop_gateway,
                logger: CompositionRoot.logger
              )
              interactor.call(input_dto)
            end

            def create
              input_dto = Domain::Crop::Dtos::NutrientRequirementUpdateInputDto.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: nutrient_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersNutrientRequirementCreateInteractor.new(
                output_port: nutrient_requirement_api_presenter,
                gateway: CompositionRoot.crop_gateway,
                logger: CompositionRoot.logger
              )
              interactor.call(input_dto)
            end

            def update
              input_dto = Domain::Crop::Dtos::NutrientRequirementUpdateInputDto.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: nutrient_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersNutrientRequirementUpdateInteractor.new(
                output_port: nutrient_requirement_api_presenter,
                gateway: CompositionRoot.crop_gateway,
                logger: CompositionRoot.logger
              )
              interactor.call(input_dto)
            end

            def destroy
              input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersNutrientRequirementDestroyInteractor.new(
                output_port: nutrient_requirement_api_presenter,
                gateway: CompositionRoot.crop_gateway,
                logger: CompositionRoot.logger
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

              @crop = bundle.persisted_crop
              @crop_stage = bundle.persisted_crop_stage
            end

            def nutrient_requirement_params
              params.require(:nutrient_requirement).permit(:daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :region)
            end

            def nutrient_requirement_api_presenter
              @nutrient_requirement_api_presenter ||= Presenters::Api::Crop::MastersNutrientRequirementApiPresenter.new(view: self)
            end
          end
        end
      end
    end
  end
end
