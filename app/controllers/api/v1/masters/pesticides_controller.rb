# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PesticidesController < BaseController
        before_action :set_pesticide, only: [:show, :update, :destroy]

        # GET /api/v1/masters/pesticides
        def index
          @pesticides = current_user.pesticides.where(is_reference: false)
          render json: @pesticides
        end

        # GET /api/v1/masters/pesticides/:id
        def show
          render json: @pesticide
        end

        # POST /api/v1/masters/pesticides
        def create
          @pesticide = current_user.pesticides.build(pesticide_params)
          @pesticide.is_reference = false

          if @pesticide.save
            render json: @pesticide, status: :created
          else
            render json: { errors: @pesticide.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/pesticides/:id
        def update
          if @pesticide.update(pesticide_params)
            render json: @pesticide
          else
            render json: { errors: @pesticide.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/pesticides/:id
        def destroy
          if @pesticide.destroy
            head :no_content
          else
            render json: { errors: @pesticide.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_pesticide
          @pesticide = current_user.pesticides.where(is_reference: false).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Pesticide not found' }, status: :not_found
        end

        def pesticide_params
          params.require(:pesticide).permit(:name, :active_ingredient, :description, :crop_id, :pest_id, :region)
        end
      end
    end
  end
end
