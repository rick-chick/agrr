# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FertilizesController < BaseController
        before_action :set_fertilize, only: [:show, :update, :destroy]

        # GET /api/v1/masters/fertilizes
        def index
          @fertilizes = current_user.fertilizes.where(is_reference: false)
          render json: @fertilizes
        end

        # GET /api/v1/masters/fertilizes/:id
        def show
          render json: @fertilize
        end

        # POST /api/v1/masters/fertilizes
        def create
          @fertilize = current_user.fertilizes.build(fertilize_params)
          @fertilize.is_reference = false

          if @fertilize.save
            render json: @fertilize, status: :created
          else
            render json: { errors: @fertilize.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/fertilizes/:id
        def update
          if @fertilize.update(fertilize_params)
            render json: @fertilize
          else
            render json: { errors: @fertilize.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/fertilizes/:id
        def destroy
          if @fertilize.destroy
            head :no_content
          else
            render json: { errors: @fertilize.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_fertilize
          @fertilize = current_user.fertilizes.where(is_reference: false).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Fertilize not found' }, status: :not_found
        end

        def fertilize_params
          params.require(:fertilize).permit(:name, :n, :p, :k, :description, :package_size, :region)
        end
      end
    end
  end
end
