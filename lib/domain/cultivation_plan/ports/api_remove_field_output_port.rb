# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class ApiRemoveFieldOutputPort
        def on_success(field_id:, total_area:)
          raise NotImplementedError
        end

        def on_not_found
          raise NotImplementedError
        end

        def on_field_not_found
          raise NotImplementedError
        end

        def on_cannot_remove_with_cultivations
          raise NotImplementedError
        end

        def on_cannot_remove_last_field
          raise NotImplementedError
        end

        def on_unexpected(message:)
          raise NotImplementedError
        end
      end
    end
  end
end
