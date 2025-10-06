# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmUpdateInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(farm_id, farm_data)
          # Check if farm exists
          unless @gateway.exists?(farm_id)
            return Domain::Shared::Result.failure("Farm not found")
          end
          
          # Validate input data
          validate_input(farm_data)
          
          # Update via gateway
          updated_farm = @gateway.update(farm_id, farm_data)
          
          Domain::Shared::Result.success(updated_farm)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end

        private

        def validate_input(data)
          raise ArgumentError, "Latitude must be between -90 and 90" if data[:latitude] && (data[:latitude] < -90 || data[:latitude] > 90)
          raise ArgumentError, "Longitude must be between -180 and 180" if data[:longitude] && (data[:longitude] < -180 || data[:longitude] > 180)
        end
      end
    end
  end
end
