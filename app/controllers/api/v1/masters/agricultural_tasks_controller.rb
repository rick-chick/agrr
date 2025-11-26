# frozen_string_literal: true

module Api
  module V1
    module Masters
      class AgriculturalTasksController < BaseController
        before_action :set_agricultural_task, only: [:show, :update, :destroy]

        # GET /api/v1/masters/agricultural_tasks
        def index
          # HTML側と同様、Policyのvisible_scopeを利用
          @agricultural_tasks = AgriculturalTaskPolicy.visible_scope(current_user)
          render json: @agricultural_tasks
        end

        # GET /api/v1/masters/agricultural_tasks/:id
        def show
          render json: @agricultural_task
        end

        # POST /api/v1/masters/agricultural_tasks
        def create
          # HTML側と同様のownershipルールをPolicyに委譲（APIではis_referenceパラメータは許可していない）
          @agricultural_task = AgriculturalTaskPolicy.build_for_create(current_user, agricultural_task_params)

          if @agricultural_task.save
            render json: @agricultural_task, status: :created
          else
            render json: { errors: @agricultural_task.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/masters/agricultural_tasks/:id
        def update
          # HTML側と同様に、更新時のownership/参照フラグ調整はPolicyに委譲
          if AgriculturalTaskPolicy.apply_update!(current_user, @agricultural_task, agricultural_task_params)
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
          @agricultural_task = AgriculturalTaskPolicy.find_editable!(current_user, params[:id])
        rescue PolicyPermissionDenied
          render json: { error: I18n.t('agricultural_tasks.flash.no_permission') }, status: :forbidden
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
