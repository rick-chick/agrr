# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PublicPlanSaveSessionDataMapper
        # @param header [Dtos::PublicPlanSaveHeaderSnapshot]
        # @param field_rows [Array<Dtos::PublicPlanSaveFieldDatum>]
        # @return [Dtos::PublicPlanSaveSessionData]
        def self.from_snapshots(header:, field_rows:)
          Dtos::PublicPlanSaveSessionData.new(
            plan_id: header.plan_id,
            farm_id: header.farm_id,
            field_data: field_rows
          )
        end
      end
    end
  end
end
