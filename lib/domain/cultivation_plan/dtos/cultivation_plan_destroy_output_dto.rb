# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanDestroyOutputDto
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
