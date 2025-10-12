# frozen_string_literal: true

class Api::V1::Farms::FarmApiController < Api::V1::BaseController
        before_action :set_interactors

        # GET /api/v1/farms
        def index
          farms = @find_all_interactor.call(current_user.id)
          
          if farms.success?
            render json: farms.data.map { |farm| farm_to_json(farm) }
          else
            render json: { error: farms.error }, status: :unprocessable_entity
          end
        end

        # GET /api/v1/farms/:id
        def show
          result = @find_interactor.call(params[:id])
          
          if result.success?
            render json: farm_to_json(result.data)
          else
            render json: { error: result.error }, status: :not_found
          end
        end

        # POST /api/v1/farms
        def create
          farm_params_with_user = farm_params.merge(user_id: current_user.id)
          result = @create_interactor.call(farm_params_with_user)
          
          if result.success?
            render json: farm_to_json(result.data), status: :created
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/farms/:id
        def update
          result = @update_interactor.call(params[:id], farm_params)
          
          if result.success?
            render json: farm_to_json(result.data)
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/farms/:id
        def destroy
          result = @delete_interactor.call(params[:id])
          
          if result.success?
            head :no_content
          else
            render json: { error: result.error }, status: :not_found
          end
        end

        private

        def set_interactors
          gateway = Adapters::Farm::Gateways::FarmMemoryGateway.new
          @create_interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(gateway)
          @find_interactor = Domain::Farm::Interactors::FarmFindInteractor.new(gateway)
          @update_interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(gateway)
          @delete_interactor = Domain::Farm::Interactors::FarmDeleteInteractor.new(gateway)
          @find_all_interactor = Domain::Farm::Interactors::FarmFindAllInteractor.new(gateway)
        end

        def farm_params
          params.require(:farm).permit(:name, :latitude, :longitude)
        end

        def farm_to_json(farm)
          {
            id: farm.id,
            name: farm.name,
            latitude: farm.latitude,
            longitude: farm.longitude,
            coordinates: farm.coordinates,
            has_coordinates: farm.has_coordinates?,
            display_name: farm.display_name,
            created_at: farm.created_at,
            updated_at: farm.updated_at
          }
        end
end
