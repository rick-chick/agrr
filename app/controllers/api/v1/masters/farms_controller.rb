# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FarmsController < BaseController

        public

        # GET /api/v1/masters/farms
        def index
          input_valid?(:index) || return

          input_dto = Domain::Farm::Dtos::FarmListInput.new(is_admin: current_user&.admin?)

          presenter = Adapters::Farm::Presenters::FarmListApiPresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmListInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.farm_gateway, translator: CompositionRoot.translator)
          interactor.call(input_dto)
        end

        # GET /api/v1/masters/farms/:id
        def show
          input_valid?(:show) || return

          presenter = Adapters::Farm::Presenters::FarmDetailApiPresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmDetailInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.farm_gateway, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup)

          interactor.call(params[:id])
        end

        # POST /api/v1/masters/farms
        def create
          input_dto = Domain::Farm::Dtos::FarmCreateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_farm_params?(input_dto)
            render_response(json: { errors: [ "name, region, latitude, longitude are required" ] }, status: :unprocessable_entity)
            return
          end
          presenter = Adapters::Farm::Presenters::FarmCreateApiPresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.farm_gateway, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/farms/:id
        def update
          input_dto = Domain::Farm::Dtos::FarmUpdateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Adapters::Farm::Presenters::FarmUpdateApiPresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/farms/:id
        def destroy
          input_valid?(:destroy) || return

          presenter = Adapters::Farm::Presenters::FarmDeleteApiPresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmDestroyInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call(params[:id])
        end

        # FarmDeleteView: undo 用 JSON の undo_path 組み立て
        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        def translator
          @translator ||= CompositionRoot.translator
        end

        private

        def entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            latitude: entity.latitude,
            longitude: entity.longitude,
            region: entity.region,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at,
            is_reference: entity.is_reference
          }
        end

        def field_entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            area: entity.area,
            daily_fixed_cost: entity.daily_fixed_cost,
            region: entity.region,
            farm_id: entity.farm_id,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at
          }
        end

        def input_valid?(action)
          case action
          when :show, :destroy
            return true if params[:id].present?
            render_response(json: { error: "Farm not found" }, status: :not_found)
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
