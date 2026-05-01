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
          # eager load associated records to avoid N+1 when serializing in data/adjust
          # Use preload to eager load associations in separate queries to avoid
          # potentially heavy join queries when using includes with complex nested associations.
          PlanPolicy
            .private_scope(current_user)
            .preload(
              :cultivation_plan_fields,
              { cultivation_plan_crops: :crop },
              { field_cultivations: [ :cultivation_plan_field, { cultivation_plan_crop: :crop } ] }
            )
            .find(params[:id])
        end

        def get_crop_for_add_crop(crop_id)
          presenter = Presenters::Api::Crop::CropRecordPresenter.new(view: self)
          Domain::Crop::Interactors::CropFindUserNonReferenceRecordInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(crop_id)

          @crop_record
        end

        def get_available_crops
          presenter = Presenters::Api::Plans::AvailableCropsPresenter.new(view: self)
          Domain::Crop::Interactors::CropListUserOwnedNonReferenceOrderedInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call

          @available_crops || []
        end
      end
    end
  end
end
