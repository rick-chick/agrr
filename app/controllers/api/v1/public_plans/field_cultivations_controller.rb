# frozen_string_literal: true

require_dependency 'field_cultivation_climate/mock_progress_records'

module Api
  module V1
    module PublicPlans
      class FieldCultivationsController < ApplicationController
        skip_before_action :verify_authenticity_token, only: [:update]
        skip_before_action :authenticate_user!, only: [:show, :climate_data, :update]
        include Views::Api::PublicPlans::FieldCultivations::FieldCultivationClimateDataView
        include ::FieldCultivationClimate::MockProgressRecords
        
        def show
          @field_cultivation = ::FieldCultivation.find(params[:id])
          cultivation_plan = @field_cultivation.cultivation_plan
          
          # public plan であることを確認（Policy 経由）
          PlanPolicy.find_public!(cultivation_plan.id)
          
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
        rescue PolicyPermissionDenied
          raise ActiveRecord::RecordNotFound
        end
        
        # GET /api/v1/public_plans/field_cultivations/:id/climate_data
        # 栽培期間の気温・GDDデータを返す（agrr progressコマンドを使用）
        def climate_data
          field_cultivation_climate_data_interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInputDto.new(
              field_cultivation_id: field_cultivation_id_param
            )
          )
        end
        
        def update
          @field_cultivation = ::FieldCultivation.find(params[:id])
          cultivation_plan = @field_cultivation.cultivation_plan
          
          # public plan であることを確認（Policy 経由）
          PlanPolicy.find_public!(cultivation_plan.id)
          
          if @field_cultivation.update(field_cultivation_params)
            # 栽培日数を再計算
            if @field_cultivation.start_date && @field_cultivation.completion_date
              days = (@field_cultivation.completion_date - @field_cultivation.start_date).to_i + 1
              @field_cultivation.update_column(:cultivation_days, days)
            end
            
            render json: {
              success: true,
              message: '栽培期間を更新しました',
              field_cultivation: {
                id: @field_cultivation.id,
                start_date: @field_cultivation.start_date,
                completion_date: @field_cultivation.completion_date,
                cultivation_days: @field_cultivation.cultivation_days
              }
            }
          else
            render json: {
              success: false,
              message: '更新に失敗しました',
              errors: @field_cultivation.errors.full_messages
            }, status: :unprocessable_entity
          end
        rescue PolicyPermissionDenied
          raise ActiveRecord::RecordNotFound
        end
        
        def render_response(json:, status:)
          render json: json, status: status
        end

        private

        def field_cultivation_climate_data_interactor
          Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor.new(
            output_port: Api::FieldCultivationClimate::FieldCultivationClimateDataPresenter.new(view: self),
            gateway: climate_gateway
          )
        end

        def climate_gateway
          Adapters::FieldCultivation::Gateways::FieldCultivationClimateGateway.new(
            current_user: current_user
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
