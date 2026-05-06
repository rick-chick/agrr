# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Ports
      class FieldCultivationApiUpdateOutputPort
        def on_success(success_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(failure)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
