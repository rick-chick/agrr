# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldFindAllInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(farm_id)
          fields = @gateway.find_by_farm_id(farm_id)
          Domain::Shared::Result.success(fields)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end
