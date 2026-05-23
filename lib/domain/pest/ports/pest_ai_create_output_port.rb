# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestAiCreateOutputPort
        def on_success(output)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(failure)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
