# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldFindInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(field_id)
          field = @gateway.find_by_id(field_id)
          
          if field
            Domain::Shared::Result.success(field)
          else
            Domain::Shared::Result.failure("Field not found")
          end
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end
