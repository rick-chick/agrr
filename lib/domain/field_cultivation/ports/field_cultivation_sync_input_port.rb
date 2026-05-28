# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Ports
      class FieldCultivationSyncInputPort
        # @param plan_id [Integer]
        # @param sync_input [Domain::FieldCultivation::Dtos::FieldCultivationSyncInput]
        def call(plan_id:, sync_input:)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
