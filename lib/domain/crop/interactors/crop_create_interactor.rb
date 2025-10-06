# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropCreateInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(attributes)
          crop = @gateway.create(attributes)
          Domain::Shared::Result.success(crop)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end


