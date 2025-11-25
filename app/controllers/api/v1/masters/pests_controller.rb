# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PestsController < BaseController
        before_action :set_pest, only: [:show, :update, :destroy]

        # GET /api/v1/masters/pests
        def index
          @pests = current_user.pests.where(is_reference: false)
          render json: @pests
        end

        # GET /api/v1/masters/pests/:id
        def show
          render json: @pest
        end

        # POST /api/v1/masters/pests
        def create
          @pest = current_user.pests.build(pest_params)
          @pest.is_reference = false

          if @pest.save
            render json: @pest, status: :created
          else
            render json: { errors: @pest.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/pests/:id
        def update
          if @pest.update(pest_params)
            render json: @pest
          else
            render json: { errors: @pest.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/pests/:id
        def destroy
          if @pest.destroy
            head :no_content
          else
            render json: { errors: @pest.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_pest
          @pest = current_user.pests.where(is_reference: false).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Pest not found' }, status: :not_found
        end

        def pest_params
          params.require(:pest).permit(:name, :name_scientific, :family, :order, :description, :occurrence_season, :region)
        end
      end
    end
  end
end
