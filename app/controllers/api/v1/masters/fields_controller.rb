# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FieldsController < BaseController
        include Views::Api::Field::FieldListView
        include Views::Api::Field::FieldDetailView
        include Views::Api::Field::FieldCreateView
        include Views::Api::Field::FieldUpdateView
        include Views::Api::Field::FieldDeleteView

        # GET /api/v1/masters/farms/:farm_id/fields
        def index
          return unless input_valid?(:index)
          presenter = Presenters::Api::Field::FieldListPresenter.new(view: self)
          interactor = Domain::Field::Interactors::FieldListInteractor.new(
            output_port: presenter,
            gateway: field_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:farm_id])
        end

        # GET /api/v1/masters/fields/:id
        def show
          input_valid?(:show) || return
          presenter = Presenters::Api::Field::FieldDetailPresenter.new(view: self)
          interactor = Domain::Field::Interactors::FieldDetailInteractor.new(
            output_port: presenter,
            gateway: field_gateway,
            user_id: current_user.id
          )
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/farms/:farm_id/fields
        def create
          return unless input_valid?(:create)
          input_dto = Domain::Field::Dtos::FieldCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_create_params?(input_dto)
            render_response(json: { errors: ['name is required'] }, status: :unprocessable_entity)
            return
          end
          presenter = Presenters::Api::Field::FieldCreatePresenter.new(view: self)
          interactor = Domain::Field::Interactors::FieldCreateInteractor.new(
            output_port: presenter,
            gateway: field_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto, params[:farm_id])
        end

        # PATCH/PUT /api/v1/masters/fields/:id
        def update
          input_valid?(:update) || return
          input_dto = Domain::Field::Dtos::FieldUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Presenters::Api::Field::FieldUpdatePresenter.new(view: self)
          interactor = Domain::Field::Interactors::FieldUpdateInteractor.new(
            output_port: presenter,
            gateway: field_gateway,
            user_id: current_user.id
          )
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/fields/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Presenters::Api::Field::FieldDeletePresenter.new(view: self)
          interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(
            output_port: presenter,
            gateway: field_gateway,
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

        def field_gateway
          @field_gateway ||= Adapters::Field::Gateways::FieldActiveRecordGateway.new
        end

        def input_valid?(action)
          case action
          when :index, :create
            return true if params[:farm_id].present?
            render_response(json: { error: 'Farm not found' }, status: :not_found)
            false
          when :show, :destroy, :update
            return true if params[:id].present?
            render_response(json: { error: 'Field not found' }, status: :not_found)
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
