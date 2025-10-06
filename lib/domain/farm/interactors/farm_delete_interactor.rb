# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmDeleteInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(farm_id)
          # Check if farm exists
          unless @gateway.exists?(farm_id)
            return Domain::Shared::Result.failure("Farm not found")
          end
          
          # Delete via gateway
          result = @gateway.delete(farm_id)
          
          Domain::Shared::Result.success(result)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end
