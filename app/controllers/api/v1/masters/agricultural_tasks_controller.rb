# frozen_string_literal: true

module Api
  module V1
    module Masters
      class AgriculturalTasksController < BaseController
        include Views::Api::AgriculturalTask::AgriculturalTaskListView
        include Views::Api::AgriculturalTask::AgriculturalTaskDetailView
        include Views::Api::AgriculturalTask::AgriculturalTaskCreateView
        include Views::Api::AgriculturalTask::AgriculturalTaskUpdateView
        include Views::Api::AgriculturalTask::AgriculturalTaskDeleteView

        # GET /api/v1/masters/agricultural_tasks
        def index
          presenter = Presenters::Api::AgriculturalTask::AgriculturalTaskListPresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskListInteractor.new(
            output_port: presenter,
            gateway: agricultural_task_gateway,
            user_id: current_user.id
          )
          interactor.call
        end

        # GET /api/v1/masters/agricultural_tasks/:id
        def show
          input_valid?(:show) || return
          presenter = Presenters::Api::AgriculturalTask::AgriculturalTaskDetailPresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDetailInteractor.new(
            output_port: presenter,
            gateway: agricultural_task_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/agricultural_tasks
        def create
          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_create_params?(input_dto)
            render_response(json: { errors: ['name is required'] }, status: :unprocessable_entity)
            return
          end
          presenter = Presenters::Api::AgriculturalTask::AgriculturalTaskCreatePresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskCreateInteractor.new(
            output_port: presenter,
            gateway: agricultural_task_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/agricultural_tasks/:id
        def update
          input_valid?(:update) || return
          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Presenters::Api::AgriculturalTask::AgriculturalTaskUpdatePresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor.new(
            output_port: presenter,
            gateway: agricultural_task_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/agricultural_tasks/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Presenters::Api::AgriculturalTask::AgriculturalTaskDeletePresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDestroyInteractor.new(
            output_port: presenter,
            gateway: agricultural_task_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        def render_response(json:, status:)
          render(json: json, status: status)
        end

        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        private

        def agricultural_task_gateway
          @agricultural_task_gateway ||= Adapters::AgriculturalTask::Gateways::AgriculturalTaskActiveRecordGateway.new
        end

        def input_valid?(action)
          case action
          when :show, :destroy, :update
            return true if params[:id].present?
            render_response(json: { error: 'AgriculturalTask not found' }, status: :not_found)
            false
          else
            true
          end
        end

        def valid_create_params?(input_dto)
          input_dto.name.present?
        end
      end
    end
  end
end
