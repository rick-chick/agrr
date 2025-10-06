# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropFindInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(id)
          crop = @gateway.find_by_id(id)
          return Domain::Shared::Result.failure("Crop not found") unless crop
          Domain::Shared::Result.success(crop)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end


