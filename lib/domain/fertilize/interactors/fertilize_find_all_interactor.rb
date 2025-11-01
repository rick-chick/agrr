# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeFindAllInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call
          fertilizes = @gateway.find_all_reference
          Domain::Shared::Result.success(fertilizes)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end

