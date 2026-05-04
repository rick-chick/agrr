# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Assemblers
      class PrivatePlanIndexPageAssembler
        def self.call(plan_rows:)
          Domain::CultivationPlan::Dtos::PrivatePlanIndexPageDto.new(plan_rows: plan_rows)
        end
      end
    end
  end
end
