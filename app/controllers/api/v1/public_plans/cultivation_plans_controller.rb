# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class CultivationPlansController < ApplicationController
        include CultivationPlanApi

        skip_before_action :verify_authenticity_token, only: [ :adjust, :data, :add_crop, :add_field, :remove_field ]
        skip_before_action :authenticate_user!, only: [ :adjust, :data, :add_crop, :add_field, :remove_field ]

        # add_crop, add_field, remove_field, data, adjust はConcernで実装




        private

        def cultivation_plan_rest_plan_data_available_crop_rows_gateway
          Adapters::CultivationPlan::Gateways::PlanDataAvailableCropRowsPublicActiveRecordGateway.new(
            crop_gateway: CompositionRoot.crop_gateway,
            logger: cultivation_plan_rest_logger
          )
        end

        def get_crop_for_add_crop(crop_id)
          ::Crop.find(crop_id)
        end

      end
    end
  end
end
