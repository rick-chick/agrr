# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateContextGateway
        def find_plan_access_context(field_cultivation_id)
          raise NotImplementedError
        end

        # @return [Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        # @raise [Domain::FieldCultivation::Errors::NoWeatherLocationError]
        # @raise [Domain::FieldCultivation::Errors::NoCultivationPeriodError]
        def load_context(field_cultivation_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
