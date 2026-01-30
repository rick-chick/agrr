# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideListOutputPort
        def on_success(pesticides)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
