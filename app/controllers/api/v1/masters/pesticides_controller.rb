# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PesticidesController < BaseController

        # GET /api/v1/masters/pesticides
        def index
          presenter = Adapters::Pesticide::Presenters::PesticideListApiPresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideListInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call
        end

        # GET /api/v1/masters/pesticides/:id
        def show
          input_valid?(:show) || return
          presenter = Adapters::Pesticide::Presenters::PesticideDetailApiPresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideDetailInteractor.new(output_port: presenter,
            user_id: current_user.id,
            show_detail_read_gateway: CompositionRoot.pesticide_show_detail_read_gateway,
            user_lookup: CompositionRoot.user_lookup)
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/pesticides
        def create
          input_dto = Domain::Pesticide::Dtos::PesticideCreateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_pesticide_params?(input_dto)
            render_response(json: { errors: [ "name, crop_id, pest_id are required" ] }, status: :unprocessable_entity)
            return
          end
          presenter = Adapters::Pesticide::Presenters::PesticideCreateApiPresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideCreateInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/pesticides/:id
        def update
          input_dto = Domain::Pesticide::Dtos::PesticideUpdateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Adapters::Pesticide::Presenters::PesticideUpdateApiPresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideUpdateInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.pesticide_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/pesticides/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Adapters::Pesticide::Presenters::PesticideDeleteApiPresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideDestroyInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.pesticide_gateway, user_lookup: CompositionRoot.user_lookup)
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
            render_response(json: { error: "Pesticide not found" }, status: :not_found)
            false
          else
            true
          end
        end

        def valid_pesticide_params?(input_dto)
          input_dto.name.present? && input_dto.crop_id.present? && input_dto.pest_id.present?
        end
      end
    end
  end
end
