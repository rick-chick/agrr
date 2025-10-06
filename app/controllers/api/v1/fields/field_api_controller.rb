# frozen_string_literal: true

class Api::V1::Fields::FieldApiController < ApplicationController
        before_action :authenticate_user!
        before_action :set_interactors
        before_action :set_farm

        # GET /api/v1/farms/:farm_id/fields
        def index
          fields = @find_all_interactor.call(@farm.id)
          
          if fields.success?
            render json: fields.data.map { |field| field_to_json(field) }
          else
            render json: { error: fields.error }, status: :unprocessable_entity
          end
        end

        # GET /api/v1/farms/:farm_id/fields/:id
        def show
          result = @find_interactor.call(params[:id])
          
          if result.success?
            render json: field_to_json(result.data)
          else
            render json: { error: result.error }, status: :not_found
          end
        end

        # POST /api/v1/farms/:farm_id/fields
        def create
          field_params_with_associations = field_params.merge(
            farm_id: @farm.id,
            user_id: current_user.id
          )
          result = @create_interactor.call(field_params_with_associations)
          
          if result.success?
            render json: field_to_json(result.data), status: :created
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/farms/:farm_id/fields/:id
        def update
          result = @update_interactor.call(params[:id], field_params)
          
          if result.success?
            render json: field_to_json(result.data)
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/farms/:farm_id/fields/:id
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
          gateway = Adapters::Field::Gateways::FieldMemoryGateway.new
          @create_interactor = Domain::Field::Interactors::FieldCreateInteractor.new(gateway)
          @find_interactor = Domain::Field::Interactors::FieldFindInteractor.new(gateway)
          @update_interactor = Domain::Field::Interactors::FieldUpdateInteractor.new(gateway)
          @delete_interactor = Domain::Field::Interactors::FieldDeleteInteractor.new(gateway)
          @find_all_interactor = Domain::Field::Interactors::FieldFindAllInteractor.new(gateway)
        end

        def set_farm
          @farm = Farm.find(params[:farm_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Farm not found" }, status: :not_found
        end

        def field_params
          params.require(:field).permit(:name, :description)
        end

        def field_to_json(field)
          {
            id: field.id,
            farm_id: field.farm_id,
            name: field.name,
            description: field.description,
            display_name: field.display_name,
            created_at: field.created_at,
            updated_at: field.updated_at
          }
        end
end
