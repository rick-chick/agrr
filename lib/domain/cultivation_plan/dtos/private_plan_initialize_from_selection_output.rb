# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PrivatePlanInitializeFromSelectionOutput
        attr_reader :id

        def initialize(id:)
          @id = id
        end
      end
    end
  end
end
