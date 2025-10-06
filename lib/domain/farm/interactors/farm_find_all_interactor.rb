# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmFindAllInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(user_id)
          farms = @gateway.find_by_user_id(user_id)
          Domain::Shared::Result.success(farms)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end
