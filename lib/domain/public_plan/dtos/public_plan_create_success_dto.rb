# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      class PublicPlanCreateSuccessDto
        attr_reader :plan_id

        def initialize(plan_id:)
          @plan_id = plan_id
        end
      end
    end
  end
end
