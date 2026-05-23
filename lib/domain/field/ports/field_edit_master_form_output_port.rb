# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldEditMasterFormOutputPort
        def on_success(farm_master_form_snapshot:, field_master_form_snapshot:)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_permission_denied(farm_id:)
          raise NotImplementedError, "Subclasses must implement on_permission_denied"
        end

        def on_not_found(farm_id:)
          raise NotImplementedError, "Subclasses must implement on_not_found"
        end
      end
    end
  end
end
