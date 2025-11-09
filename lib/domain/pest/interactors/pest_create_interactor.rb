# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestCreateInteractor
        def initialize(gateway)
          @gateway = gateway
        end
        
        def call(attributes)
          pest = @gateway.create(attributes)
          Domain::Shared::Result.success(pest)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end








