# frozen_string_literal: true

module Domain
  module InteractionRule
    module Ports
      class InteractionRuleListOutputPort
        def on_success(rules)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
