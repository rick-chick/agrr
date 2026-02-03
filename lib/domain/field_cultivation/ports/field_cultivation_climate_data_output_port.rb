# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Ports
      class FieldCultivationClimateDataOutputPort
        def present(success_dto)
          raise NotImplementedError, "Subclasses must implement present"
        end

        def on_success(success_dto)
          present(success_dto)
        end

        def on_error(error_dto)
          raise NotImplementedError, "Subclasses must implement on_error"
        end

        def on_failure(error_dto)
          on_error(error_dto)
        end
      end
    end
  end
end
