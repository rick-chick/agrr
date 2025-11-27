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
        include CultivationPlanApi
        
        before_action :authenticate_user!
        skip_before_action :verify_authenticity_token
        
        # add_crop, add_field, remove_field, data, adjust はConcernで実装
        
        private
        
        def find_api_cultivation_plan
          PlanPolicy
            .private_scope(current_user)
            .includes(
              field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop],
              cultivation_plan_fields: [],
              cultivation_plan_crops: []
            )
            .find(params[:id])
        end
        
        def get_crop_for_add_crop(crop_id)
          CropPolicy.visible_scope(current_user).find_by(id: crop_id, is_reference: false)
        end
      end
    end
  end
end

