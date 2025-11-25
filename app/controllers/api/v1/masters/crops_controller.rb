# frozen_string_literal: true

module Api
  module V1
    module Masters
      class CropsController < BaseController
        before_action :set_crop, only: [:show, :update, :destroy]

        # GET /api/v1/masters/crops
        def index
          @crops = current_user.crops.where(is_reference: false)
          render json: @crops
        end

        # GET /api/v1/masters/crops/:id
        def show
          render json: @crop
        end

        # POST /api/v1/masters/crops
        def create
          @crop = current_user.crops.build(crop_params)
          @crop.is_reference = false

          if @crop.save
            render json: @crop, status: :created
          else
            render json: { errors: @crop.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/crops/:id
        def update
          if @crop.update(crop_params)
            render json: @crop
          else
            render json: { errors: @crop.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/crops/:id
        def destroy
          if @crop.destroy
            head :no_content
          else
            render json: { errors: @crop.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_crop
          @crop = current_user.crops.where(is_reference: false).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Crop not found' }, status: :not_found
        end

        def crop_params
          params.require(:crop).permit(:name, :variety, :area_per_unit, :revenue_per_area, :region, groups: [])
        end
      end
    end
  end
end
