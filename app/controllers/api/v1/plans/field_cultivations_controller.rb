# frozen_string_literal: true


module Api
  module V1
    module Plans
      class FieldCultivationsController < ApplicationController
        before_action :authenticate_user!
        skip_before_action :verify_authenticity_token, only: [ :update ]
        include ::Adapters::FieldCultivation::MockProgressRecords

        def show
          field_cultivation_api_show_interactor.call(field_cultivation_id: params[:id])
        end

        # GET /api/v1/plans/field_cultivations/:id/climate_data
        # 栽培期間の気温・GDDデータを返す（agrr progressコマンドを使用）
        def climate_data
          field_cultivation_climate_data_interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: field_cultivation_id_param,
              display_start_date: params[:display_start_date],
              display_end_date: params[:display_end_date]
            )
          )
        end

        # PATCH /api/v1/plans/field_cultivations/:id
        def update
          field_cultivation_api_update_interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInput.new(
              field_cultivation_id: params[:id],
              start_date: field_cultivation_params[:start_date],
              completion_date: field_cultivation_params[:completion_date],
              public_plan: false
            )
          )
        end

        def render_response(json:, status:)
          render json: json, status: status
        end

        private

        def field_cultivation_plan_api_gateway
          CompositionRoot.field_cultivation_climate_gateway_for(
            CompositionRoot.user_lookup.find(current_user.id)
          )
        end

        def field_cultivation_api_show_interactor
          Domain::FieldCultivation::Interactors::FieldCultivationShowInteractor.new(
            output_port: Adapters::FieldCultivation::Presenters::Api::FieldCultivationApiShowPresenter.new(view: self),
            gateway: field_cultivation_plan_api_gateway
          )
        end

        def field_cultivation_api_update_interactor
          Domain::FieldCultivation::Interactors::FieldCultivationUpdateInteractor.new(
            output_port: Adapters::FieldCultivation::Presenters::Api::FieldCultivationApiUpdatePresenter.new(view: self),
            gateway: field_cultivation_plan_api_gateway
          )
        end

        def field_cultivation_climate_data_interactor
          uid = current_user.id
          Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor.new(
            output_port: Adapters::FieldCultivation::Presenters::Api::FieldCultivationClimateDataPresenter.new(view: self),
            gateway: CompositionRoot.field_cultivation_climate_gateway_for(CompositionRoot.user_lookup.find(uid)),
            logger: CompositionRoot.logger
          )
        end

        def field_cultivation_id_param
          params.require(:id)
        end

        def field_cultivation_params
          params.require(:field_cultivation).permit(:start_date, :completion_date)
        end

      end
    end
  end
end
