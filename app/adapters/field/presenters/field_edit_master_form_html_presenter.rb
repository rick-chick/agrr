# frozen_string_literal: true

module Adapters
  module Field
    module Presenters
      class FieldEditMasterFormHtmlPresenter < Domain::Field::Ports::FieldEditMasterFormOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_master_form_snapshot:, field_master_form_snapshot:)
          @view.instance_variable_set(:@farm, Forms::FarmMasterForm.from_snapshot(farm_master_form_snapshot))
          @view.instance_variable_set(:@field, Forms::FieldMasterForm.from_snapshot(field_master_form_snapshot))
        end

        def on_permission_denied(farm_id:)
          @view.redirect_to @view.farm_fields_path(farm_id), alert: I18n.t("fields.flash.no_permission")
        end

        def on_not_found(farm_id:)
          @view.redirect_to @view.url_for(controller: "fields", action: "index", farm_id: farm_id),
                            alert: I18n.t("fields.flash.not_found")
        end
      end
    end
  end
end
