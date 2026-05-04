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

        def cultivation_plan_rest_plan_data_available_crop_rows_gateway
          Adapters::CultivationPlan::Gateways::PlanDataAvailableCropRowsPrivateActiveRecordGateway.new(
            crop_gateway: CompositionRoot.crop_gateway,
            user_lookup: CompositionRoot.user_lookup,
            logger: cultivation_plan_rest_logger
          )
        end

        def get_crop_for_add_crop(crop_id)
          presenter = Presenters::Api::Crop::CropRecordPresenter.new(view: self)
          Domain::Crop::Interactors::CropFindUserNonReferenceRecordInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(crop_id)

          @crop_record
        end

      end
    end
  end
end
