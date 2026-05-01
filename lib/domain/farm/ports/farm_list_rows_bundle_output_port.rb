# frozen_string_literal: true

module Domain
  module Farm
    module Ports
      class FarmListRowsBundleOutputPort
        def on_success(rows_bundle_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
