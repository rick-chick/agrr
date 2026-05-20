# frozen_string_literal: true

module Domain
  module Fertilize
    module Ports
      class FertilizeLoadOutputPort
        def on_success(bundle)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_permission_denied
          raise NotImplementedError, "Subclasses must implement on_permission_denied"
        end

        def on_not_found
          raise NotImplementedError, "Subclasses must implement on_not_found"
        end
      end
    end
  end
end
