# frozen_string_literal: true

module Api
  module V1
    module Masters
      class AgriculturalTasksController < BaseController

        # GET /api/v1/masters/agricultural_tasks
        def index
          presenter = Adapters::AgriculturalTask::Presenters::Api::AgriculturalTaskListPresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskListInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call
        end

        # GET /api/v1/masters/agricultural_tasks/:id
        def show
          input_valid?(:show) || return
          presenter = Adapters::AgriculturalTask::Presenters::Api::AgriculturalTaskDetailPresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDetailInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/agricultural_tasks
        def create
          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskCreateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_create_params?(input_dto)
            render_response(json: { errors: [ "name is required" ] }, status: :unprocessable_entity)
            return
          end
          presenter = Adapters::AgriculturalTask::Presenters::Api::AgriculturalTaskCreatePresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskCreateInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/agricultural_tasks/:id
        def update
          input_valid?(:update) || return
          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Adapters::AgriculturalTask::Presenters::Api::AgriculturalTaskUpdatePresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/agricultural_tasks/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Adapters::AgriculturalTask::Presenters::Api::AgriculturalTaskDeletePresenter.new(view: self)
          interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDestroyInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.agricultural_task_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call(params[:id])
        end

        def render_response(json:, status:)
          render(json: json, status: status)
        end

        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        private


        def input_valid?(action)
          case action
          when :show, :destroy, :update
            return true if params[:id].present?
            render_response(json: { error: "AgriculturalTask not found" }, status: :not_found)
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
