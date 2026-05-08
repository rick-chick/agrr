# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class MastersNutrientRequirementOutputPort
        def on_show_success(requirement_entity)
          raise NotImplementedError, "Subclasses must implement on_show_success"
        end

        def on_create_success(requirement_entity)
          raise NotImplementedError, "Subclasses must implement on_create_success"
        end

        def on_update_success(requirement_entity)
          raise NotImplementedError, "Subclasses must implement on_update_success"
        end

        def on_not_found
          raise NotImplementedError, "Subclasses must implement on_not_found"
        end

        def on_already_exists
          raise NotImplementedError, "Subclasses must implement on_already_exists"
        end

        def on_validation_errors(error_messages)
          raise NotImplementedError, "Subclasses must implement on_validation_errors"
        end

        def on_destroy_success
          raise NotImplementedError, "Subclasses must implement on_destroy_success"
        end
      end
    end
  end
end
