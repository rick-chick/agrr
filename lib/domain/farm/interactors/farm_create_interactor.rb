# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmCreateInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(farm_data)
          # Validate input data
          validate_input(farm_data)
          
          # Create farm entity
          farm_entity = Entities::FarmEntity.new(farm_data)
          
          # Save via gateway
          created_farm = @gateway.create(farm_data)
          
          Domain::Shared::Result.success(created_farm)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end

        private

        def validate_input(data)
          raise ArgumentError, "Name is required" if data[:name].blank?
          raise ArgumentError, "User ID is required" if data[:user_id].blank?
        end
      end
    end
  end
end
