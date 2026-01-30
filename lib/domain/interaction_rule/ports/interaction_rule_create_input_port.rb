# frozen_string_literal: true

module Domain
  module InteractionRule
    module Ports
      class InteractionRuleCreateInputPort
        def call(create_input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
