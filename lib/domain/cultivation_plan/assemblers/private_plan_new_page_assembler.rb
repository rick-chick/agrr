# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Assemblers
      class PrivatePlanNewPageAssembler
        def self.call(farm_choices:, default_plan_name:)
          Domain::CultivationPlan::Dtos::PrivatePlanNewPageDto.new(
            farm_choices: farm_choices,
            default_plan_name: default_plan_name
          )
        end
      end
    end
  end
end
