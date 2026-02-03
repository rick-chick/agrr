# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationGateway
        def fetch_field_cultivation_climate_data(field_cultivation_id:)
          raise NotImplementedError, "Subclasses must implement fetch_field_cultivation_climate_data"
        end
      end
    end
  end
end
