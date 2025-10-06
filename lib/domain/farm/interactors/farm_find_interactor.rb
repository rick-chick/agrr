# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmFindInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(farm_id)
          farm = @gateway.find_by_id(farm_id)
          
          if farm
            Domain::Shared::Result.success(farm)
          else
            Domain::Shared::Result.failure("Farm not found")
          end
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end
