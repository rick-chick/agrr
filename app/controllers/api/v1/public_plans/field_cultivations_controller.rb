# frozen_string_literal: true

require_dependency "field_cultivation_climate/mock_progress_records"

module Api
  module V1
    module PublicPlans
      class FieldCultivationsController < ApplicationController
        skip_before_action :verify_authenticity_token, only: [ :update ]
        skip_before_action :authenticate_user!, only: [ :show, :climate_data, :update ]
        include Views::Api::PublicPlans::FieldCultivations::FieldCultivationClimateDataView
        include ::FieldCultivationClimate::MockProgressRecords

        def show
          field_cultivation_api_show_interactor.call(field_cultivation_id: params[:id])
        end

        # GET /api/v1/public_plans/field_cultivations/:id/climate_data
        # 栽培期間の気温・GDDデータを返す（agrr progressコマンドを使用）
        def climate_data
          field_cultivation_climate_data_interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInputDto.new(
              field_cultivation_id: field_cultivation_id_param,
              display_start_date: params[:display_start_date],
              display_end_date: params[:display_end_date]
            )
          )
        end

        def update
          field_cultivation_api_update_interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInputDto.new(
              field_cultivation_id: params[:id],
              start_date: field_cultivation_params[:start_date],
              completion_date: field_cultivation_params[:completion_date],
              public_plan: true
            )
          )
        end

        def render_response(json:, status:)
          render json: json, status: status
        end

        private

        def field_cultivation_plan_api_gateway
          uid = current_user&.id
          user_dto = uid ? CompositionRoot.user_lookup.find(uid) : nil
          CompositionRoot.field_cultivation_climate_gateway_for(user_dto)
        end

        def field_cultivation_api_show_interactor
          Domain::FieldCultivation::Interactors::FieldCultivationApiShowInteractor.new(
            output_port: Presenters::Api::FieldCultivation::FieldCultivationApiShowPresenter.new(view: self),
            gateway: field_cultivation_plan_api_gateway
          )
        end

        def field_cultivation_api_update_interactor
          Domain::FieldCultivation::Interactors::FieldCultivationApiUpdateInteractor.new(
            output_port: Presenters::Api::FieldCultivation::FieldCultivationApiUpdatePresenter.new(view: self),
            gateway: field_cultivation_plan_api_gateway
          )
        end

        def field_cultivation_climate_data_interactor
          uid = current_user.id
          Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor.new(
            output_port: Presenters::Api::FieldCultivationClimate::FieldCultivationClimateDataPresenter.new(view: self),
            gateway: CompositionRoot.field_cultivation_climate_gateway_for(CompositionRoot.user_lookup.find(uid)),
            logger: CompositionRoot.logger
          )
        end

        def field_cultivation_params
          params.require(:field_cultivation).permit(:start_date, :completion_date)
        end

        def field_cultivation_id_param
          params.require(:id)
        end

      end
    end
  end
end
