# frozen_string_literal: true

require_dependency 'field_cultivation_climate/mock_progress_records'

module Api
  module V1
    module Plans
      class FieldCultivationsController < ApplicationController
        before_action :authenticate_user!
        skip_before_action :verify_authenticity_token, only: [:update]
        include Views::Api::Plans::FieldCultivations::FieldCultivationClimateDataView
        include ::FieldCultivationClimate::MockProgressRecords
        
        def show
          @field_cultivation = find_field_cultivation
          
          render json: {
            id: @field_cultivation.id,
            field_name: @field_cultivation.field_display_name,
            crop_name: @field_cultivation.crop_display_name,
            area: @field_cultivation.area,
            start_date: @field_cultivation.start_date,
            completion_date: @field_cultivation.completion_date,
            cultivation_days: @field_cultivation.cultivation_days,
            estimated_cost: @field_cultivation.estimated_cost,
            gdd: @field_cultivation.optimization_result&.dig('raw', 'total_gdd'),
            status: @field_cultivation.status
          }
        end
        
        # GET /api/v1/plans/field_cultivations/:id/climate_data
        # 栽培期間の気温・GDDデータを返す（agrr progressコマンドを使用）
        def climate_data
          field_cultivation_climate_data_interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInputDto.new(
              field_cultivation_id: field_cultivation_id_param
            )
          )
        end
        
        # PATCH /api/v1/plans/field_cultivations/:id
        def update
          @field_cultivation = find_field_cultivation
          
          if @field_cultivation.update(field_cultivation_params)
            render json: {
              success: true,
              field_cultivation: {
                id: @field_cultivation.id,
                start_date: @field_cultivation.start_date,
                completion_date: @field_cultivation.completion_date
              }
            }
          else
            render json: {
              success: false,
              errors: @field_cultivation.errors.full_messages
            }, status: :unprocessable_entity
          end
        end
        
        def render_response(json:, status:)
          render json: json, status: status
        end

        private

        def climate_gateway
          Adapters::FieldCultivation::Gateways::FieldCultivationClimateGateway.new(
            current_user: current_user
          )
        end

        def field_cultivation_climate_data_interactor
          Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor.new(
            output_port: Api::FieldCultivationClimate::FieldCultivationClimateDataPresenter.new(view: self),
            gateway: climate_gateway
          )
        end

        def field_cultivation_id_param
          params.require(:id)
        end

        def find_field_cultivation
          field_cultivation = ::FieldCultivation.find(params[:id])
          cultivation_plan = field_cultivation.cultivation_plan

          # ユーザーの private 計画であることを確認（Policy 経由）
          PlanPolicy.find_private_owned!(current_user, cultivation_plan.id)

          field_cultivation
        rescue PolicyPermissionDenied
          raise ActiveRecord::RecordNotFound
        end

        def field_cultivation_params
          params.require(:field_cultivation).permit(:start_date, :completion_date)
        end
      end
    end
  end
end

