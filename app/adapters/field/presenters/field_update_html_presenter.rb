# frozen_string_literal: true

module Adapters
  module Field
    module Presenters
      class FieldUpdateHtmlPresenter < Domain::Field::Ports::FieldUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(field_entity)
          @view.redirect_to @view.farm_field_path(field_entity.farm_id, field_entity.id),
                            notice: I18n.t("fields.flash.updated")
        end

        def on_failure(error_dto)
          @view.redirect_to @view.farm_fields_path(@view.params[:farm_id]), alert: error_dto.message
        end
      end
    end
  end
end
