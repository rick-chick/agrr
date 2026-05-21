# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      class PesticideDestroyHtmlPresenter < Domain::Pesticide::Ports::PesticideDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          event = destroy_output_dto.undo
          if event&.undo_token.present?
            resource_label = event.metadata["resource_label"]
            @view.redirect_back fallback_location: @view.pesticides_path,
                               notice: I18n.t("deletion_undo.redirect_notice", resource: resource_label)
          else
            # undo トークンがない場合は通常のリダイレクト
            @view.redirect_to @view.pesticides_path, notice: I18n.t("pesticides.flash.destroyed")
          end
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.pesticides_path,
                               alert: I18n.t("pesticides.flash.no_permission")
            return
          end

          @view.redirect_back fallback_location: @view.pesticides_path, alert: error_dto.message
        end
      end
    end
  end
end
