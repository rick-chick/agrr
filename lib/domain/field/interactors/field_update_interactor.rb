# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldUpdateInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(field_id, field_data)
          # Check if field exists
          unless @gateway.exists?(field_id)
            return Domain::Shared::Result.failure("Field not found")
          end
          
          # Validate input data
          validate_input(field_data)
          
          # Update via gateway
          updated_field = @gateway.update(field_id, field_data)
          
          Domain::Shared::Result.success(updated_field)
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
