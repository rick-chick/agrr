# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Ports
      class FieldCultivationApiShowOutputPort
        def on_success(summary_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
