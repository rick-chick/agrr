# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeFindInteractor
        def initialize(gateway)
          @gateway = gateway
        end
        
        def call(id)
          fertilize = @gateway.find_by_id(id)
          return Domain::Shared::Result.failure("Fertilize not found") unless fertilize
          Domain::Shared::Result.success(fertilize)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end

