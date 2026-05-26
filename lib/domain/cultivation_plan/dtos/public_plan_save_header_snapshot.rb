# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PublicPlanSaveReadGateway の find_header 戻り値。
      class PublicPlanSaveHeaderSnapshot
        attr_reader :plan_id, :farm_id

        def initialize(plan_id:, farm_id:)
          @plan_id = plan_id.to_i
          @farm_id = farm_id&.to_i
          freeze
        end
      end
    end
  end
end
