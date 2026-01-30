# frozen_string_literal: true

module Api
  module V1
    module Masters
      class PesticidesController < BaseController
        # PolicyPermissionDenied例外を403 Forbiddenとして扱う
        rescue_from Domain::Shared::Policies::PolicyPermissionDenied do |exception|
          render json: { error: '権限がありません。' }, status: :forbidden
        end

        include Views::Api::Pesticide::PesticideListView
        include Views::Api::Pesticide::PesticideDetailView
        include Views::Api::Pesticide::PesticideCreateView
        include Views::Api::Pesticide::PesticideUpdateView
        include Views::Api::Pesticide::PesticideDeleteView

        # GET /api/v1/masters/pesticides
        def index
          presenter = Presenters::Api::Pesticide::PesticideListPresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideListInteractor.new(
            output_port: presenter,
            gateway: pesticide_gateway,
            user_id: current_user.id
          )
          interactor.call
        end

        # GET /api/v1/masters/pesticides/:id
        def show
          input_valid?(:show) || return
          presenter = Presenters::Api::Pesticide::PesticideDetailPresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideDetailInteractor.new(
            output_port: presenter,
            gateway: pesticide_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/pesticides
        def create
          input_dto = Domain::Pesticide::Dtos::PesticideCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_pesticide_params?(input_dto)
            render_response(json: { errors: ['name, crop_id, pest_id are required'] }, status: :unprocessable_entity)
            return
          end
          presenter = Presenters::Api::Pesticide::PesticideCreatePresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideCreateInteractor.new(
            output_port: presenter,
            gateway: pesticide_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/pesticides/:id
        def update
          input_dto = Domain::Pesticide::Dtos::PesticideUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Presenters::Api::Pesticide::PesticideUpdatePresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideUpdateInteractor.new(
            output_port: presenter,
            gateway: pesticide_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/pesticides/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Presenters::Api::Pesticide::PesticideDeletePresenter.new(view: self)
          interactor = Domain::Pesticide::Interactors::PesticideDestroyInteractor.new(
            output_port: presenter,
            gateway: pesticide_gateway,
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

        def pesticide_gateway
          @pesticide_gateway ||= Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new
        end

        def input_valid?(action)
          case action
          when :show, :destroy
            return true if params[:id].present?
            render_response(json: { error: 'Pesticide not found' }, status: :not_found)
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
