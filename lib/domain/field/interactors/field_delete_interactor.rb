# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldDeleteInteractor
        def initialize(gateway)
          @gateway = gateway
        end

        def call(field_id)
          # Check if field exists
          unless @gateway.exists?(field_id)
            return Domain::Shared::Result.failure("Field not found")
          end
          
          # Delete via gateway
          result = @gateway.delete(field_id)
          
          Domain::Shared::Result.success(result)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end
