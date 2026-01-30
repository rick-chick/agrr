# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          # 生育ステージと栄養素要件の関連管理API
          class NutrientRequirementsController < BaseController
            before_action :set_crop
            before_action :set_crop_stage

            def show
              @requirement = @crop_stage.nutrient_requirement
              if @requirement
                render json: @requirement
              else
                render json: { error: 'NutrientRequirement not found' }, status: :not_found
              end
            end

            def create
              if @crop_stage.nutrient_requirement
                render json: { error: 'NutrientRequirement already exists' }, status: :unprocessable_entity
                return
              end

              @requirement = @crop_stage.build_nutrient_requirement(nutrient_requirement_params)

              if @requirement.save
                render json: @requirement, status: :created
              else
                render json: { errors: @requirement.errors.full_messages }, status: :unprocessable_entity
              end
            end

            def update
              @requirement = @crop_stage.nutrient_requirement
              unless @requirement
                render json: { error: 'NutrientRequirement not found' }, status: :not_found
                return
              end

              if @requirement.update(nutrient_requirement_params)
                render json: @requirement
              else
                render json: { errors: @requirement.errors.full_messages }, status: :unprocessable_entity
              end
            end

            def destroy
              @requirement = @crop_stage.nutrient_requirement
              unless @requirement
                render json: { error: 'NutrientRequirement not found' }, status: :not_found
                return
              end

              if @requirement.destroy
                head :no_content
              else
                render json: { errors: @requirement.errors.full_messages }, status: :unprocessable_entity
              end
            end

            private

            def set_crop
              @crop = Domain::Shared::Policies::CropPolicy.visible_scope(Crop, current_user).where(is_reference: false).find(params[:crop_id])
            rescue ActiveRecord::RecordNotFound
              render json: { error: 'Crop not found' }, status: :not_found
            end

            def set_crop_stage
              @crop_stage = @crop.crop_stages.find(params[:crop_stage_id])
            rescue ActiveRecord::RecordNotFound
              render json: { error: 'CropStage not found' }, status: :not_found
            end

            def nutrient_requirement_params
              params.require(:nutrient_requirement).permit(:daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :region)
            end
          end
        end
      end
    end
  end
end
