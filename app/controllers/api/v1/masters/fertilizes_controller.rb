# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FertilizesController < BaseController
        include Views::Api::Fertilize::FertilizeListView
        include Views::Api::Fertilize::FertilizeDetailView
        include Views::Api::Fertilize::FertilizeCreateView
        include Views::Api::Fertilize::FertilizeUpdateView
        include Views::Api::Fertilize::FertilizeDeleteView

        # GET /api/v1/masters/fertilizes
        def index
          presenter = Presenters::Api::Fertilize::FertilizeListPresenter.new(view: self)
          interactor = Domain::Fertilize::Interactors::FertilizeListInteractor.new(
            output_port: presenter,
            gateway: fertilize_gateway,
            user_id: current_user.id
          )
          interactor.call
        end

        # GET /api/v1/masters/fertilizes/:id
        def show
          input_valid?(:show) || return
          presenter = Presenters::Api::Fertilize::FertilizeDetailPresenter.new(view: self)
          interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(
            output_port: presenter,
            gateway: fertilize_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/fertilizes
        def create
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_fertilize_params?(input_dto)
            render_response(json: { errors: ['name is required'] }, status: :unprocessable_entity)
            return
          end
          presenter = Presenters::Api::Fertilize::FertilizeCreatePresenter.new(view: self)
          interactor = Domain::Fertilize::Interactors::FertilizeCreateInteractor.new(
            output_port: presenter,
            gateway: fertilize_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/fertilizes/:id
        def update
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Presenters::Api::Fertilize::FertilizeUpdatePresenter.new(view: self)
          interactor = Domain::Fertilize::Interactors::FertilizeUpdateInteractor.new(
            output_port: presenter,
            gateway: fertilize_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/fertilizes/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Presenters::Api::Fertilize::FertilizeDeletePresenter.new(view: self)
          interactor = Domain::Fertilize::Interactors::FertilizeDestroyInteractor.new(
            output_port: presenter,
            gateway: fertilize_gateway,
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

        def fertilize_gateway
          @fertilize_gateway ||= Adapters::Fertilize::Gateways::FertilizeMemoryGateway.new
        end

        def input_valid?(action)
          case action
          when :show, :destroy
            return true if params[:id].present?
            render_response(json: { error: 'Fertilize not found' }, status: :not_found)
            false
          else
            true
          end
        end

        def valid_fertilize_params?(input_dto)
          input_dto.name.present?
        end
      end
    end
  end
end
