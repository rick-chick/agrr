# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class PlanSaveUserPesticideGateway
        # @return [Dtos::PlanSaveUserPesticideSnapshot, nil]
        def find_by_user_id_and_source_pesticide_id(user_id:, source_pesticide_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param attributes [Hash]
        # @param usage_constraint_attributes [Hash, nil]
        # @param application_detail_attributes [Hash, nil]
        # @return [Dtos::PlanSaveUserPesticideSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(
          user_id:,
          attributes:,
          usage_constraint_attributes: nil,
          application_detail_attributes: nil
        )
          raise NotImplementedError
        end
      end
    end
  end
end
