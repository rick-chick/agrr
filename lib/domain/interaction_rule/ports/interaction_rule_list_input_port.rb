# frozen_string_literal: true

module Domain
  module InteractionRule
    module Ports
      class InteractionRuleListInputPort
        def call
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
