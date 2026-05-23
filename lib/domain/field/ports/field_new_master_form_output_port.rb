# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldHtmlNewMasterFormOutputPort
        # @param master_form_snapshot [Domain::Farm::Dtos::FieldMasterFormSnapshot]
        def on_success(master_form_snapshot)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
