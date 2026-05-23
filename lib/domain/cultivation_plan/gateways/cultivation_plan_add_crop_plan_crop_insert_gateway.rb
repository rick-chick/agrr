# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # add_crop: cultivation_plan_crops へ1件追加（永続化のみ）。
      class CultivationPlanAddCropPlanCropInsertGateway
        def initialize(logger:)
          @logger = logger
        end

        # @param crop_entity [#id, #name, #variety, #area_per_unit, #revenue_per_area]
        # @return [Hash] :success（plan_crop_id, plan_crop_display_name） / :not_found / :record_invalid / :unexpected
        def create_plan_crop!(auth:, plan_id:, crop_entity:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
