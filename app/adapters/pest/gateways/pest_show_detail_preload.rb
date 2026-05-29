# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      module PestShowDetailPreload
        module_function

        def find!(id)
          ::Pest.includes(
            :pest_temperature_profile,
            :pest_thermal_requirement,
            :pest_control_methods,
            :crops
          ).find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
