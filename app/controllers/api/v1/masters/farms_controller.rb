# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FarmsController < BaseController
        include ApiCrudResponder
        before_action :set_farm, only: [:show, :update, :destroy]

        # GET /api/v1/masters/farms
        def index
          @farms = FarmPolicy.user_owned_scope(current_user)
          respond_to_index(@farms)
        end

        # GET /api/v1/masters/farms/:id
        def show
          respond_to_show(@farm)
        end

        # POST /api/v1/masters/farms
        def create
          @farm = FarmPolicy.build_for_create(current_user, farm_params)
          @farm.save
          respond_to_create(@farm)
        end

        # PATCH/PUT /api/v1/masters/farms/:id
        def update
          update_result = @farm.update(farm_params)
          respond_to_update(@farm, update_result: update_result)
        end

        # DELETE /api/v1/masters/farms/:id
        def destroy
          destroy_result = @farm.destroy
          respond_to_destroy(@farm, destroy_result: destroy_result)
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
