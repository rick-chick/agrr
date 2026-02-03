# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Ports
      class FieldCultivationClimateDataInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
