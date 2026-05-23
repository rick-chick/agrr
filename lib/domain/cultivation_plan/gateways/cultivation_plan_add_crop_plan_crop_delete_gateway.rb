# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # add_crop: 失敗時ロールバック用の plan_crop 削除。
      class CultivationPlanAddCropPlanCropDeleteGateway
        def initialize(logger:)
          @logger = logger
        end

        # @return [Hash] :success | :not_found | :unexpected
        def destroy_plan_crop!(plan_crop_id:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
