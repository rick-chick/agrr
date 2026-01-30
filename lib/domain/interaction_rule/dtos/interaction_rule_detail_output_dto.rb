# frozen_string_literal: true

module Domain
  module InteractionRule
    module Dtos
      class InteractionRuleDetailOutputDto
        attr_reader :rule

        def initialize(rule:)
          @rule = rule
        end
      end
    end
  end
end
