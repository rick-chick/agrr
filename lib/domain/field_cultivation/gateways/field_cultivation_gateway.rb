# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationGateway
        def fetch_field_cultivation_climate_data(field_cultivation_id:, display_start_date: nil, display_end_date: nil)
          raise NotImplementedError, "Subclasses must implement fetch_field_cultivation_climate_data"
        end

        def climate_data_fallback_dto(field_cultivation_id:, display_start_date: nil, display_end_date: nil)
          raise NotImplementedError, "Subclasses must implement climate_data_fallback_dto"
        end

        def fetch_api_summary(field_cultivation_id:)
          raise NotImplementedError, "Subclasses must implement fetch_api_summary"
        end

        def update_field_cultivation_schedule(field_cultivation_id:, start_date:, completion_date:, public_plan: false)
          raise NotImplementedError, "Subclasses must implement update_field_cultivation_schedule"
        end
      end
    end
  end
end
