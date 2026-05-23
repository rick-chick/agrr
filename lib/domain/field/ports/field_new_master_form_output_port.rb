# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldNewMasterFormOutputPort
        def on_success(farm_master_form_snapshot:, field_master_form_snapshot:)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
