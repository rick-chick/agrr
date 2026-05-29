# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationGateway
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)
          raise NotImplementedError,
                "Subclasses must implement find_plan_access_snapshot_by_field_cultivation_id"
        end

        # @return [Domain::FieldCultivation::Dtos::FieldCultivationApiSummary]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_api_summary_by_field_cultivation_id(field_cultivation_id)
          raise NotImplementedError,
                "Subclasses must implement find_api_summary_by_field_cultivation_id"
        end

        # @return [Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutput]
        def update_field_cultivation_schedule(field_cultivation_id:, start_date:, completion_date:, cultivation_days: nil)
          raise NotImplementedError, "Subclasses must implement update_field_cultivation_schedule"
        end
      end
    end
  end
end
