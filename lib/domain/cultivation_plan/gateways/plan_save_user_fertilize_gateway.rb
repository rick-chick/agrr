# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class PlanSaveUserFertilizeGateway
        # @return [Dtos::PlanSaveUserFertilizeSnapshot, nil]
        def find_by_user_id_and_source_fertilize_id(user_id:, source_fertilize_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param attributes [Hash]
        # @return [Dtos::PlanSaveUserFertilizeSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(user_id:, attributes:)
          raise NotImplementedError
        end
      end
    end
  end
end
