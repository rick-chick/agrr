# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeCreateInteractor
        def initialize(gateway)
          @gateway = gateway
        end
        
        def call(attributes)
          fertilize = @gateway.create(attributes)
          Domain::Shared::Result.success(fertilize)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end

