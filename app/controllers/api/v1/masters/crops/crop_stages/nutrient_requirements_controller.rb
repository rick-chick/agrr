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
              input_dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersNutrientRequirementShowInteractor.new(
                output_port: nutrient_requirement_presenter,
                gateway: CompositionRoot.crop_gateway,
                requirement_gateway: CompositionRoot.nutrient_requirement_gateway
              )
              interactor.call(input_dto)
            end

            def create
              input_dto = Domain::Crop::Dtos::NutrientRequirementUpdateInput.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: nutrient_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersNutrientRequirementCreateInteractor.new(
                output_port: nutrient_requirement_presenter,
                gateway: CompositionRoot.crop_gateway,
                requirement_gateway: CompositionRoot.nutrient_requirement_gateway
              )
              interactor.call(input_dto)
            end

            def update
              input_dto = Domain::Crop::Dtos::NutrientRequirementUpdateInput.new(
                crop_id: @crop.id,
                stage_id: @crop_stage.id,
                payload: nutrient_requirement_params.to_h.symbolize_keys
              )

              interactor = Domain::Crop::Interactors::MastersNutrientRequirementUpdateInteractor.new(
                output_port: nutrient_requirement_presenter,
                gateway: CompositionRoot.crop_gateway,
                requirement_gateway: CompositionRoot.nutrient_requirement_gateway
              )
              interactor.call(input_dto)
            end

            def destroy
              input_dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: @crop_stage.id)

              interactor = Domain::Crop::Interactors::MastersNutrientRequirementDestroyInteractor.new(
                output_port: nutrient_requirement_presenter,
                gateway: CompositionRoot.crop_gateway,
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

            def nutrient_requirement_params
              params.require(:nutrient_requirement).permit(:daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :region)
            end

            def nutrient_requirement_presenter
              @nutrient_requirement_presenter ||= Adapters::Crop::Presenters::MastersNutrientRequirementApiPresenter.new(view: self)
            end
          end
        end
      end
    end
  end
end
