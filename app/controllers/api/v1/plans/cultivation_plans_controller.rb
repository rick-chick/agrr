# frozen_string_literal: true

module Api
  module V1
    module Plans
      # 個人計画用のAPIコントローラー
      # public_plans版との主な違い：
      # - 認証必須
      # - ユーザー自身の計画のみアクセス可能
      # - ユーザー作物・ユーザー農場のみ使用
      class CultivationPlansController < Api::V1::CultivationPlanRestBaseController
        before_action :authenticate_user!
        skip_before_action :verify_authenticity_token

        # add_crop, add_field, remove_field, data, adjust は Api::V1::CultivationPlanRestBaseController で実装

        private

        def cultivation_plan_rest_plan_data_available_crop_rows_gateway
          Adapters::CultivationPlan::Gateways::CropRowsAvailablePrivateActiveRecordGateway.new(
            crop_gateway: CompositionRoot.crop_gateway,
            user_lookup: CompositionRoot.user_lookup,
            logger: cultivation_plan_rest_logger
          )
        end

      end
    end
  end
end
