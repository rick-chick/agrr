# frozen_string_literal: true

class Api::V1::PublicPlansController < Api::V1::BaseController
  # API用の無料作付け計画保存アクション
  def save_plan
    Rails.logger.info "🔍 [API PublicPlans#save_plan] Called"

    # 認証チェック（BaseControllerで処理済み）

    # JSON body から plan_id を取得
    plan_id = params[:plan_id]
    unless plan_id.present?
      Rails.logger.warn "❌ [API PublicPlans#save_plan] plan_id is missing"
      render json: { success: false, error: 'plan_id is required' }, status: :bad_request
      return
    end

    begin
      # CultivationPlan を取得
      cultivation_plan = CultivationPlan.find(plan_id)

      # セッションデータを構築（PlanSaveService用）
      field_data = cultivation_plan.cultivation_plan_fields.map do |field|
        {
          name: field.name,
          area: field.area,
          coordinates: [35.0, 139.0] # デフォルト座標
        }
      end

      save_data = {
        plan_id: cultivation_plan.id,
        farm_id: cultivation_plan.farm_id,
        crop_ids: cultivation_plan.crops.pluck(:id),
        field_data: field_data
      }

      # PlanSaveService を呼び出し
      result = PlanSaveService.new(
        user: current_user,
        session_data: save_data
      ).call

      if result.success
        Rails.logger.info "✅ [API PublicPlans#save_plan] Plan saved successfully"
        render json: { success: true }
      else
        Rails.logger.error "❌ [API PublicPlans#save_plan] Save failed: #{result.error_message}"
        render json: { success: false, error: result.error_message || 'Save failed' }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "❌ [API PublicPlans#save_plan] Plan not found: #{plan_id}"
      render json: { success: false, error: 'Plan not found' }, status: :not_found
    rescue => e
      Rails.logger.error "❌ [API PublicPlans#save_plan] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { success: false, error: 'Internal server error' }, status: :internal_server_error
    end
  end
end