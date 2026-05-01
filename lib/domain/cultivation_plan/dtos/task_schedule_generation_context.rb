# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # TaskScheduleGenerateInteractor 向け。CultivationPlan AR をドメインに渡さない。
      class TaskScheduleGenerationContext
        attr_reader :plan

        def initialize(plan:)
          @plan = plan
        end
      end
    end
  end
end
