# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldCreateInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(field_data)
          # Validate input data
          validate_input(field_data)
          
          # Create field entity
          field_entity = Entities::FieldEntity.new(field_data)
          
          # Save via gateway
          created_field = @gateway.create(field_data)
          
          Domain::Shared::Result.success(created_field)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end

        private

        def validate_input(data)
          raise ArgumentError, "Name is required" if data[:name].blank?
          raise ArgumentError, "Farm ID is required" if data[:farm_id].blank?
          raise ArgumentError, "User ID is required" if data[:user_id].blank?
        end
      end
    end
  end
end
