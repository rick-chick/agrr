# frozen_string_literal: true

module Api
  module V1
    module Masters
      class AgriculturalTasksController < BaseController
        include ApiCrudResponder
        before_action :set_agricultural_task, only: [:show, :update, :destroy]

        # GET /api/v1/masters/agricultural_tasks
        def index
          # HTML側と同様、Policyのvisible_scopeを利用
          @agricultural_tasks = AgriculturalTaskPolicy.visible_scope(current_user)
          respond_to_index(@agricultural_tasks)
        end

        # GET /api/v1/masters/agricultural_tasks/:id
        def show
          respond_to_show(@agricultural_task)
        end

        # POST /api/v1/masters/agricultural_tasks
        def create
          # HTML側と同様のownershipルールをPolicyに委譲（APIではis_referenceパラメータは許可していない）
          @agricultural_task = AgriculturalTaskPolicy.build_for_create(current_user, agricultural_task_params)
          @agricultural_task.save
          respond_to_create(@agricultural_task)
        end

        # PATCH/PUT /api/v1/masters/agricultural_tasks/:id
        def update
          # HTML側と同様に、更新時のownership/参照フラグ調整はPolicyに委譲
          update_result = AgriculturalTaskPolicy.apply_update!(current_user, @agricultural_task, agricultural_task_params)
          respond_to_update(@agricultural_task, update_result: update_result)
        end

        # DELETE /api/v1/masters/agricultural_tasks/:id
        def destroy
          destroy_result = @agricultural_task.destroy
          respond_to_destroy(@agricultural_task, destroy_result: destroy_result)
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
