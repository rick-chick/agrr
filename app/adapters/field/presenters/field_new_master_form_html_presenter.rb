# frozen_string_literal: true

module Adapters
  module Field
    module Presenters
      class FieldNewMasterFormHtmlPresenter < Domain::Field::Ports::FieldNewMasterFormOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(master_form_snapshot)
          @view.instance_variable_set(:@field, Forms::FieldMasterForm.from_snapshot(master_form_snapshot))
        end
      end
    end
  end
end
