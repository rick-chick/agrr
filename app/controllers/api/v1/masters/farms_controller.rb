# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FarmsController < BaseController
        include Views::Api::Farm::FarmListView
        include Views::Api::Farm::FarmDetailView
        include Views::Api::Farm::FarmCreateView
        include Views::Api::Farm::FarmUpdateView
        include Views::Api::Farm::FarmDeleteView

        # GET /api/v1/masters/farms
        def index
          input_valid?(:index) || return
          presenter = Presenters::Api::Farm::FarmListPresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmListInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id
          )
          interactor.call
        end

        # GET /api/v1/masters/farms/:id
        def show
          input_valid?(:show) || return
          presenter = Presenters::Api::Farm::FarmDetailPresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmDetailInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/farms
        def create
          input_dto = Domain::Farm::Dtos::FarmCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_farm_params?(input_dto)
            render_response(json: { errors: ['name, region, latitude, longitude are required'] }, status: :unprocessable_entity)
            return
          end
          presenter = Presenters::Api::Farm::FarmCreatePresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/farms/:id
        def update
          input_dto = Domain::Farm::Dtos::FarmUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Presenters::Api::Farm::FarmUpdatePresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/farms/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Presenters::Api::Farm::FarmDeletePresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmDestroyInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        # View の実装: render は controller.render への委譲のみ
        def render_response(json:, status:)
          render(json: json, status: status)
        end

        # FarmDeleteView: undo 用 JSON の undo_path 組み立て
        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        private

        def farm_gateway
          @farm_gateway ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new
        end

        def input_valid?(action)
          case action
          when :show, :destroy
            return true if params[:id].present?
            render_response(json: { error: 'Farm not found' }, status: :not_found)
            false
          else
            true
          end
        end

        def valid_farm_params?(input_dto)
          input_dto.name.present? && input_dto.region.present? &&
            !input_dto.latitude.nil? && !input_dto.longitude.nil?
        end
      end
    end
  end
end
