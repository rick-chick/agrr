# frozen_string_literal: true

module Domain
  module InteractionRule
    module Ports
      class InteractionRuleUpdateInputPort
        def call(update_input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
