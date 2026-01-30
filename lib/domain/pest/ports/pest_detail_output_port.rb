# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestDetailOutputPort
        def on_success(pest_detail_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
