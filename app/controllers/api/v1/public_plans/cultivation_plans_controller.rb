# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class CultivationPlansController < Api::V1::CultivationPlanRestBaseController
        skip_before_action :verify_authenticity_token, only: [ :adjust, :data, :add_crop, :add_field, :remove_field ]
        skip_before_action :authenticate_user!, only: [ :adjust, :data, :add_crop, :add_field, :remove_field ]

        # add_crop, add_field, remove_field, data, adjust は Api::V1::CultivationPlanRestBaseController で実装

        private

        def cultivation_plan_rest_plan_data_available_crop_rows_gateway
          Adapters::CultivationPlan::Gateways::CropRowsAvailablePublicActiveRecordGateway.new(
            crop_gateway: CompositionRoot.crop_gateway,
            logger: cultivation_plan_rest_logger
          )
        end

      end
    end
  end
end
