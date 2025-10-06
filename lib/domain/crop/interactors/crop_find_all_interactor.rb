# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropFindAllInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(user_id)
          crops = @gateway.find_all_visible_for(user_id)
          Domain::Shared::Result.success(crops)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end


