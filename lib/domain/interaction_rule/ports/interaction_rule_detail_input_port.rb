# frozen_string_literal: true

module Domain
  module InteractionRule
    module Ports
      class InteractionRuleDetailInputPort
        def call(rule_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
