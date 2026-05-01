# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # プライベート計画一覧（HTML index）用。ActiveRecord は含めない。
      class PrivatePlanIndexPageDto
        attr_reader :plan_rows

        # @param plan_rows [Array<Domain::CultivationPlan::Dtos::PrivatePlanIndexPlanRowDto>] 表示順（農場グループを flatten した順）
        def initialize(plan_rows:)
          @plan_rows = plan_rows
        end

        def empty?
          @plan_rows.empty?
        end
      end
    end
  end
end
