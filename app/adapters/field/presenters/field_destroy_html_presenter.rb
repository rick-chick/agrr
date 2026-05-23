# frozen_string_literal: true

module Adapters
  module Field
    module Presenters
      class FieldDestroyHtmlPresenter < Domain::Field::Ports::FieldDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          farm_id = destroy_output_dto.undo.metadata.fetch("farm_id")
          event = destroy_output_dto.undo
          if event&.undo_token.present?
            resource_label = event.metadata["resource_label"]
            @view.redirect_back fallback_location: @view.farm_fields_path(farm_id),
                               notice: I18n.t("deletion_undo.redirect_notice", resource: resource_label)
          else
            @view.redirect_to @view.farm_fields_path(farm_id), notice: I18n.t("fields.flash.destroyed")
          end
        end

        def on_failure(error_dto)
          farm_id = @view.params[:farm_id]
          @view.redirect_back fallback_location: @view.farm_fields_path(farm_id), alert: error_dto.message
        end
      end
    end
  end
end
