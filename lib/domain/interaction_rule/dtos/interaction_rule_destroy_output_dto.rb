# frozen_string_literal: true

module Domain
  module InteractionRule
    module Dtos
      class InteractionRuleDestroyOutputDto
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
