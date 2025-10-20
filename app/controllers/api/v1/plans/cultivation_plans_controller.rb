# frozen_string_literal: true

module Api
  module V1
    module Plans
      # 個人計画用のAPIコントローラー
      # public_plans版との主な違い：
      # - 認証必須
      # - ユーザー自身の計画のみアクセス可能
      # - ユーザー作物・ユーザー農場のみ使用
      class CultivationPlansController < ApplicationController
        before_action :authenticate_user!
        skip_before_action :verify_authenticity_token
        
        # POST /api/v1/plans/cultivation_plans/:id/add_crop
        # 作物追加と再最適化
        def add_crop
          Rails.logger.info "🌱 [Plans Add Crop] ========== START =========="
          Rails.logger.info "🌱 [Plans Add Crop] cultivation_plan_id: #{params[:id]}, crop_id: #{params[:crop_id]}"
          
          @cultivation_plan = find_cultivation_plan
          
          # ユーザーの作物を取得
          crop = current_user.crops.find_by(id: params[:crop_id], is_reference: false)
          unless crop
            return render json: {
              success: false,
              message: I18n.t('plans.errors.crop_not_found')
            }, status: :not_found
          end
          
          # cultivation_plan_crops に追加（スナップショット）
          plan_crop = @cultivation_plan.cultivation_plan_crops.create!(
            name: crop.name,
            variety: crop.variety,
            area_per_unit: crop.area_per_unit,
            revenue_per_area: crop.revenue_per_area,
            agrr_crop_id: crop.id
          )
          
          # 再最適化
          OptimizeCultivationPlanJob.perform_later(@cultivation_plan.id)
          
          render json: {
            success: true,
            message: I18n.t('plans.messages.crop_added'),
            crop: {
              id: plan_crop.id,
              name: plan_crop.display_name
            }
          }
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.error "❌ [Plans Add Crop] Not found: #{e.message}"
          render json: { success: false, message: I18n.t('plans.errors.not_found') }, status: :not_found
        rescue => e
          Rails.logger.error "❌ [Plans Add Crop] Error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { success: false, message: e.message }, status: :internal_server_error
        end
        
        # POST /api/v1/plans/cultivation_plans/:id/add_field
        # 新しい圃場を追加
        def add_field
          @cultivation_plan = find_cultivation_plan
          farm = @cultivation_plan.farm
          
          # ユーザーの農場であることを確認
          unless farm.user_id == current_user.id
            return render json: {
              success: false,
              message: I18n.t('plans.errors.unauthorized')
            }, status: :forbidden
          end
          
          # パラメータ取得
          field_name = params[:field_name]
          field_area = params[:field_area].to_f
          daily_fixed_cost = params[:daily_fixed_cost].to_f
          
          # バリデーション
          if field_name.blank? || field_area <= 0
            return render json: {
              success: false,
              message: I18n.t('plans.errors.invalid_field_params')
            }, status: :unprocessable_entity
          end
          
          # cultivation_plan_fields に追加
          plan_field = @cultivation_plan.cultivation_plan_fields.create!(
            name: field_name,
            area: field_area,
            daily_fixed_cost: daily_fixed_cost
          )
          
          # total_areaを更新
          @cultivation_plan.update!(total_area: @cultivation_plan.cultivation_plan_fields.sum(:area))
          
          render json: {
            success: true,
            message: I18n.t('plans.messages.field_added'),
            field: {
              id: plan_field.id,
              name: plan_field.name,
              area: plan_field.area
            },
            total_area: @cultivation_plan.total_area
          }
        rescue => e
          Rails.logger.error "❌ [Plans Add Field] Error: #{e.message}"
          render json: { success: false, message: e.message }, status: :internal_server_error
        end
        
        # DELETE /api/v1/plans/cultivation_plans/:id/remove_field/:field_id
        # 圃場を削除
        def remove_field
          @cultivation_plan = find_cultivation_plan
          
          plan_field = @cultivation_plan.cultivation_plan_fields.find(params[:field_id])
          
          # 最後の圃場は削除できない
          if @cultivation_plan.cultivation_plan_fields.count <= 1
            return render json: {
              success: false,
              message: I18n.t('plans.errors.cannot_remove_last_field')
            }, status: :unprocessable_entity
          end
          
          # 圃場を削除（field_cultivationsも連鎖削除される）
          plan_field.destroy!
          
          # total_areaを更新
          @cultivation_plan.update!(total_area: @cultivation_plan.cultivation_plan_fields.sum(:area))
          
          # 再最適化
          OptimizeCultivationPlanJob.perform_later(@cultivation_plan.id)
          
          render json: {
            success: true,
            message: I18n.t('plans.messages.field_removed'),
            total_area: @cultivation_plan.total_area
          }
        rescue ActiveRecord::RecordNotFound
          render json: { success: false, message: I18n.t('plans.errors.field_not_found') }, status: :not_found
        rescue => e
          Rails.logger.error "❌ [Plans Remove Field] Error: #{e.message}"
          render json: { success: false, message: e.message }, status: :internal_server_error
        end
        
        # GET /api/v1/plans/cultivation_plans/:id/data
        # 栽培計画データを取得
        def data
          @cultivation_plan = find_cultivation_plan
          
          # 計画データを構築
          fields_data = @cultivation_plan.cultivation_plan_fields.map do |field|
            {
              id: field.id,
              name: field.display_name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            }
          end
          
          crops_data = @cultivation_plan.cultivation_plan_crops.map do |crop|
            {
              id: crop.id,
              name: crop.display_name,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area
            }
          end
          
          cultivations_data = @cultivation_plan.field_cultivations.map do |fc|
            {
              id: fc.id,
              field_id: fc.cultivation_plan_field_id,
              field_name: fc.field_display_name,
              crop_id: fc.cultivation_plan_crop_id,
              crop_name: fc.crop_display_name,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: fc.cultivation_days,
              estimated_cost: fc.estimated_cost,
              status: fc.status
            }
          end
          
          render json: {
            success: true,
            data: {
              id: @cultivation_plan.id,
              plan_year: @cultivation_plan.plan_year,
              plan_name: @cultivation_plan.plan_name,
              status: @cultivation_plan.status,
              total_area: @cultivation_plan.total_area,
              planning_start_date: @cultivation_plan.planning_start_date,
              planning_end_date: @cultivation_plan.planning_end_date,
              fields: fields_data,
              crops: crops_data,
              cultivations: cultivations_data
            }
          }
        rescue => e
          Rails.logger.error "❌ [Plans Data] Error: #{e.message}"
          render json: { success: false, message: e.message }, status: :internal_server_error
        end
        
        # POST /api/v1/plans/cultivation_plans/:id/adjust
        # 手修正後の再最適化
        def adjust
          @cultivation_plan = find_cultivation_plan
          
          # 最適化ジョブを再実行
          OptimizeCultivationPlanJob.perform_later(@cultivation_plan.id)
          
          render json: {
            success: true,
            message: I18n.t('plans.messages.reoptimization_started')
          }
        rescue => e
          Rails.logger.error "❌ [Plans Adjust] Error: #{e.message}"
          render json: { success: false, message: e.message }, status: :internal_server_error
        end
        
        private
        
        def find_cultivation_plan
          plan = CultivationPlan
            .plan_type_private
            .includes(
              field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop],
              cultivation_plan_fields: [],
              cultivation_plan_crops: []
            )
            .find(params[:id])
          
          # ユーザーの計画であることを確認
          unless plan.user_id == current_user.id
            raise ActiveRecord::RecordNotFound
          end
          
          plan
        end
      end
    end
  end
end

