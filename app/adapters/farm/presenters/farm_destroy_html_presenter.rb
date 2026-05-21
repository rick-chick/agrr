# frozen_string_literal: true

module Adapters
  module Farm
    module Presenters
      class FarmDestroyHtmlPresenter < Domain::Farm::Ports::FarmDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          event = destroy_output_dto.undo
          if event&.undo_token.present?
            resource_label = event.metadata["resource_label"]
            @view.redirect_back fallback_location: @view.farms_path,
                               notice: I18n.t("deletion_undo.redirect_notice", resource: resource_label)
          else
            # undo トークンがない場合は通常のリダイレクト
            @view.redirect_to @view.farms_path, notice: I18n.t("farms.flash.destroyed")
          end
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.farms_path,
                               alert: I18n.t("farms.flash.no_permission")
            return
          end

          @view.redirect_back fallback_location: @view.farms_path, alert: error_dto.message
        end
      end
    end
  end
end
