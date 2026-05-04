# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class ApiAddFieldOutputPort
        def on_success(field_id:, name:, area:, total_area:)
          raise NotImplementedError
        end

        def on_not_found
          raise NotImplementedError
        end

        def on_invalid_field_params
          raise NotImplementedError
        end

        def on_max_fields_limit
          raise NotImplementedError
        end

        def on_record_invalid(message:)
          raise NotImplementedError
        end

        def on_unexpected(message:)
          raise NotImplementedError
        end
      end
    end
  end
end
