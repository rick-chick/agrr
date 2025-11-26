# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FarmsController < BaseController
        before_action :set_farm, only: [:show, :update, :destroy]

        # GET /api/v1/masters/farms
        def index
          @farms = FarmPolicy.user_owned_scope(current_user)
          render json: @farms
        end

        # GET /api/v1/masters/farms/:id
        def show
          render json: @farm
        end

        # POST /api/v1/masters/farms
        def create
          @farm = FarmPolicy.build_for_create(current_user, farm_params)

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
          @farm =
            begin
              FarmPolicy.find_owned!(current_user, params[:id])
            rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
              nil
            end

          unless @farm
            render json: { error: 'Farm not found' }, status: :not_found
          end
        end

        def farm_params
          params.require(:farm).permit(:name, :latitude, :longitude, :region)
        end
      end
    end
  end
end
