# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Assemblers
      class PrivatePlanNewAssembler
        def self.call(farm_choices:, default_plan_name:)
          Domain::CultivationPlan::Dtos::PrivatePlanNew.new(
            farm_choices: farm_choices,
            default_plan_name: default_plan_name
          )
        end
      end
    end
  end
end
