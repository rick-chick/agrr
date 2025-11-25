# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FarmsController < BaseController
        before_action :set_farm, only: [:show, :update, :destroy]

        # GET /api/v1/masters/farms
        def index
          @farms = current_user.farms.where(is_reference: false)
          render json: @farms
        end

        # GET /api/v1/masters/farms/:id
        def show
          render json: @farm
        end

        # POST /api/v1/masters/farms
        def create
          @farm = current_user.farms.build(farm_params)
          @farm.is_reference = false

          if @farm.save
            render json: @farm, status: :created
          else
            render json: { errors: @farm.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/farms/:id
        def update
          if @farm.update(farm_params)
            render json: @farm
          else
            render json: { errors: @farm.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/farms/:id
        def destroy
          if @farm.destroy
            head :no_content
          else
            render json: { errors: @farm.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_farm
          @farm = current_user.farms.where(is_reference: false).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Farm not found' }, status: :not_found
        end

        def farm_params
          params.require(:farm).permit(:name, :latitude, :longitude, :region)
        end
      end
    end
  end
end
