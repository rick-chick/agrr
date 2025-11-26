# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          # 生育ステージと積算温度要件の関連管理API
          class ThermalRequirementsController < BaseController
            before_action :set_crop
            before_action :set_crop_stage

            def show
              @requirement = @crop_stage.thermal_requirement
              if @requirement
                render json: @requirement
              else
                render json: { error: 'ThermalRequirement not found' }, status: :not_found
              end
            end

            def create
              if @crop_stage.thermal_requirement
                render json: { error: 'ThermalRequirement already exists' }, status: :unprocessable_entity
                return
              end

              @requirement = @crop_stage.build_thermal_requirement(thermal_requirement_params)

              if @requirement.save
                render json: @requirement, status: :created
              else
                render json: { errors: @requirement.errors.full_messages }, status: :unprocessable_entity
              end
            end

            def update
              @requirement = @crop_stage.thermal_requirement
              unless @requirement
                render json: { error: 'ThermalRequirement not found' }, status: :not_found
                return
              end

              if @requirement.update(thermal_requirement_params)
                render json: @requirement
              else
                render json: { errors: @requirement.errors.full_messages }, status: :unprocessable_entity
              end
            end

            def destroy
              @requirement = @crop_stage.thermal_requirement
              unless @requirement
                render json: { error: 'ThermalRequirement not found' }, status: :not_found
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
              @crop = current_user.crops.where(is_reference: false).find(params[:crop_id])
            rescue ActiveRecord::RecordNotFound
              render json: { error: 'Crop not found' }, status: :not_found
            end

            def set_crop_stage
              @crop_stage = @crop.crop_stages.find(params[:crop_stage_id])
            rescue ActiveRecord::RecordNotFound
              render json: { error: 'CropStage not found' }, status: :not_found
            end

            def thermal_requirement_params
              params.require(:thermal_requirement).permit(:required_gdd)
            end
          end
        end
      end
    end
  end
end
