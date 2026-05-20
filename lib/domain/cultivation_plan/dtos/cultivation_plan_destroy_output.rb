# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanDestroyOutput
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
