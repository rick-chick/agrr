# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PestsController < BaseController

        # GET /api/v1/masters/pests
        def index
          presenter = Adapters::Pest::Presenters::PestListApiPresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestListInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.pest_gateway, translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup)
          interactor.call
        end

        # GET /api/v1/masters/pests/:id
        def show
          input_valid?(:show) || return
          presenter = Adapters::Pest::Presenters::PestDetailApiPresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestDetailInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/pests
        def create
          input_dto = Domain::Pest::Dtos::PestCreateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_pest_params?(input_dto)
            render_response(json: { errors: [ "name is required" ] }, status: :unprocessable_entity)
            return
          end
          presenter = Adapters::Pest::Presenters::PestCreateApiPresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestCreateInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.pest_gateway,
            crop_gateway: CompositionRoot.crop_gateway,
            crop_pest_gateway: CompositionRoot.crop_pest_gateway,
            user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/pests/:id
        def update
          input_dto = Domain::Pest::Dtos::PestUpdateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Adapters::Pest::Presenters::PestUpdateApiPresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestUpdateInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.pest_gateway,
            crop_gateway: CompositionRoot.crop_gateway,
            crop_pest_gateway: CompositionRoot.crop_pest_gateway,
            logger: CompositionRoot.logger,
            user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/pests/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Adapters::Pest::Presenters::PestDeleteApiPresenter.new(view: self)
          interactor = Domain::Pest::Interactors::PestDestroyInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call(params[:id])
        end

        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        private

        def input_valid?(action)
          case action
          when :show, :destroy
            return true if params[:id].present?
            render_response(json: { error: "Pest not found" }, status: :not_found)
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
