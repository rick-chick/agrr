# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropDeleteInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(id)
          deleted = @gateway.delete(id)
          if deleted
            Domain::Shared::Result.success(true)
          else
            Domain::Shared::Result.failure("Crop not found")
          end
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end


