# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeDeleteInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(fertilize_id)
          # Check if fertilize exists
          unless @gateway.exists?(fertilize_id)
            return Domain::Shared::Result.failure("Fertilize not found")
          end
          
          # Delete via gateway
          result = @gateway.delete(fertilize_id)
          
          Domain::Shared::Result.success(result)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end

