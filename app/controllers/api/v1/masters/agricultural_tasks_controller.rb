# frozen_string_literal: true

module Api
  module V1
    module Masters
      class AgriculturalTasksController < BaseController
        before_action :set_agricultural_task, only: [:show, :update, :destroy]

        # GET /api/v1/masters/agricultural_tasks
        def index
          @agricultural_tasks = current_user.agricultural_tasks.where(is_reference: false)
          render json: @agricultural_tasks
        end

        # GET /api/v1/masters/agricultural_tasks/:id
        def show
          render json: @agricultural_task
        end

        # POST /api/v1/masters/agricultural_tasks
        def create
          @agricultural_task = current_user.agricultural_tasks.build(agricultural_task_params)
          @agricultural_task.is_reference = false

          if @agricultural_task.save
            render json: @agricultural_task, status: :created
          else
            render json: { errors: @agricultural_task.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/agricultural_tasks/:id
        def update
          if @agricultural_task.update(agricultural_task_params)
            render json: @agricultural_task
          else
            render json: { errors: @agricultural_task.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/masters/agricultural_tasks/:id
        def destroy
          if @agricultural_task.destroy
            head :no_content
          else
            render json: { errors: @agricultural_task.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_agricultural_task
          @agricultural_task = current_user.agricultural_tasks.where(is_reference: false).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'AgriculturalTask not found' }, status: :not_found
        end

        def agricultural_task_params
          params.require(:agricultural_task).permit(:name, :description, :time_per_sqm, :weather_dependency, :required_tools, :skill_level, :region, :task_type)
        end
      end
    end
  end
end
