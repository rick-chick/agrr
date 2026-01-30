# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PestsController < BaseController
        include Views::Api::Pest::PestListView
        include Views::Api::Pest::PestDetailView
        include Views::Api::Pest::PestCreateView
        include Views::Api::Pest::PestUpdateView
        include Views::Api::Pest::PestDeleteView

        # GET /api/v1/masters/pests
        def index
          presenter = Presenters::Api::Pest::PestListPresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestListInteractor.new(
            output_port: presenter,
            gateway: pest_gateway,
            user_id: current_user.id
          )
          interactor.call
        end

        # GET /api/v1/masters/pests/:id
        def show
          input_valid?(:show) || return
          presenter = Presenters::Api::Pest::PestDetailPresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestDetailInteractor.new(
            output_port: presenter,
            gateway: pest_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/pests
        def create
          input_dto = Domain::Pest::Dtos::PestCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_pest_params?(input_dto)
            render_response(json: { errors: ['name is required'] }, status: :unprocessable_entity)
            return
          end
          presenter = Presenters::Api::Pest::PestCreatePresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestCreateInteractor.new(
            output_port: presenter,
            gateway: pest_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/pests/:id
        def update
          input_dto = Domain::Pest::Dtos::PestUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Presenters::Api::Pest::PestUpdatePresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestUpdateInteractor.new(
            output_port: presenter,
            gateway: pest_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/pests/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Presenters::Api::Pest::PestDeletePresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestDestroyInteractor.new(
            output_port: presenter,
            gateway: pest_gateway,
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

        def pest_gateway
          @pest_gateway ||= Adapters::Pest::Gateways::PestMemoryGateway.new
        end

        def input_valid?(action)
          case action
          when :show, :destroy
            return true if params[:id].present?
            render_response(json: { error: 'Pest not found' }, status: :not_found)
            false
          else
            true
          end
        end

        def valid_pest_params?(input_dto)
          input_dto.name.present?
        end
      end
    end
  end
end
