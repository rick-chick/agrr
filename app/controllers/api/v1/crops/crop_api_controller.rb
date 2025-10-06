# frozen_string_literal: true

class Api::V1::Crops::CropApiController < ApplicationController
        before_action :authenticate_user!
        before_action :set_interactors

        # GET /api/v1/crops
        def index
          crops = @find_all_interactor.call(current_user.id)
          if crops.success?
            render json: crops.data.map { |crop| crop_to_json(crop) }
          else
            render json: { error: crops.error }, status: :unprocessable_entity
          end
        end

        # GET /api/v1/crops/:id
        def show
          result = @find_interactor.call(params[:id])
          if result.success?
            render json: crop_to_json(result.data)
          else
            render json: { error: result.error }, status: :not_found
          end
        end

        # POST /api/v1/crops
        def create
          is_reference = crop_params[:is_reference] || false
          if is_reference && !current_user.admin?
            return render json: { error: "Only admin can create reference crops" }, status: :forbidden
          end

          attrs = crop_params.merge(user_id: (is_reference ? nil : current_user.id))
          result = @create_interactor.call(attrs)
          if result.success?
            render json: crop_to_json(result.data), status: :created
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/crops/:id
        def update
          if crop_params.key?(:is_reference) && !current_user.admin?
            return render json: { error: "Only admin can change reference flag" }, status: :forbidden
          end

          result = @update_interactor.call(params[:id], crop_params)
          if result.success?
            render json: crop_to_json(result.data)
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/crops/:id
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
          gateway = Adapters::Crop::Gateways::CropMemoryGateway.new
          @create_interactor = Domain::Crop::Interactors::CropCreateInteractor.new(gateway)
          @find_interactor = Domain::Crop::Interactors::CropFindInteractor.new(gateway)
          @update_interactor = Domain::Crop::Interactors::CropUpdateInteractor.new(gateway)
          @delete_interactor = Domain::Crop::Interactors::CropDeleteInteractor.new(gateway)
          @find_all_interactor = Domain::Crop::Interactors::CropFindAllInteractor.new(gateway)
        end

        def crop_params
          params.require(:crop).permit(:name, :variety, :is_reference)
        end

        def crop_to_json(crop)
          {
            crop_id: crop.id,
            crop_name: crop.name,
            variety: crop.variety,
            is_reference: crop.reference?,
            stages: (crop.respond_to?(:stages) ? crop.stages.map { |stage| stage_to_json(stage) } : [])
          }
        end

        def stage_to_json(stage)
          {
            name: stage.name,
            order: stage.order,
            temperature: stage.temperature && {
              base_temperature: stage.temperature[:base_temperature],
              optimal_min: stage.temperature[:optimal_min],
              optimal_max: stage.temperature[:optimal_max],
              low_stress_threshold: stage.temperature[:low_stress_threshold],
              high_stress_threshold: stage.temperature[:high_stress_threshold],
              frost_threshold: stage.temperature[:frost_threshold],
              sterility_risk_threshold: stage.temperature[:sterility_risk_threshold]
            },
            sunshine: stage.sunshine && {
              minimum_sunshine_hours: stage.sunshine[:minimum_sunshine_hours],
              target_sunshine_hours: stage.sunshine[:target_sunshine_hours]
            },
            thermal: stage.thermal && {
              required_gdd: stage.thermal[:required_gdd]
            }
          }
        end
end


