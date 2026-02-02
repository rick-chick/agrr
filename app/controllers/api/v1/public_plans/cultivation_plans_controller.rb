# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class CultivationPlansController < ApplicationController
        include CultivationPlanApi
        
        skip_before_action :verify_authenticity_token, only: [:adjust, :data, :add_crop, :add_field, :remove_field]
        skip_before_action :authenticate_user!, only: [:adjust, :data, :add_crop, :add_field, :remove_field]
        
        # add_crop, add_field, remove_field, data, adjust はConcernで実装
        
        
        
        
        private
        
        # Concernで実装すべきメソッド
        
        def find_api_cultivation_plan
          # public plan であることを確認（Policy 経由）
          plan = PlanPolicy.find_public!(params[:id])
          
          ::CultivationPlan
            .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
            .find(plan.id)
        rescue PolicyPermissionDenied
          raise ActiveRecord::RecordNotFound
        end
        
        def get_crop_for_add_crop(crop_id)
          ::Crop.find(crop_id)
        end
      end
    end
  end
end

