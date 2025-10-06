# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropUpdateInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(id, attributes)
          crop = @gateway.update(id, attributes)
          Domain::Shared::Result.success(crop)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end


