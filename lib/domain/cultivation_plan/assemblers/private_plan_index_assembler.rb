# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Assemblers
      class PrivatePlanIndexAssembler
        def self.call(plan_rows:)
          Domain::CultivationPlan::Dtos::PrivatePlanIndexDto.new(plan_rows: plan_rows)
        end
      end
    end
  end
end
