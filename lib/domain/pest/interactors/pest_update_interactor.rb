# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestUpdateInteractor
        def initialize(gateway)
          @gateway = gateway
        end
        
        def call(id, attributes)
          pest = @gateway.update(id, attributes)
          Domain::Shared::Result.success(pest)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end




