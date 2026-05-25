# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PublicPlanSaveReadGateway の find_header 戻り値。
      class PublicPlanSaveHeaderSnapshot
        attr_reader :plan_id, :farm_id, :crop_ids

        def initialize(plan_id:, farm_id:, crop_ids:)
          @plan_id = plan_id.to_i
          @farm_id = farm_id&.to_i
          @crop_ids = Array(crop_ids).map(&:to_i).freeze
          freeze
        end
      end
    end
  end
end
