# frozen_string_literal: true

module Adapters
  module Fertilize
    module Presenters
      class FertilizeUpdateHtmlPresenter < Domain::Fertilize::Ports::FertilizeUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(fertilize_entity)
          @view.redirect_to(
            @view.fertilize_path(fertilize_entity.id),
            notice: I18n.t("fertilizes.flash.updated")
          )
        end

        def on_failure(failure_dto)
          if failure_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.fertilizes_path,
                               alert: I18n.t("fertilizes.flash.no_permission")
            return
          end

          msg = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s
          fertilize_id = failure_dto.respond_to?(:master_form_snapshot) ? failure_dto.master_form_snapshot&.id : @view.params[:id]

          if msg == I18n.t("fertilizes.flash.reference_flag_admin_only") && fertilize_id
            @view.redirect_to @view.fertilize_path(fertilize_id), alert: msg
            return
          end

          path = fertilize_id ? @view.fertilize_path(fertilize_id) : @view.fertilizes_path
          @view.redirect_to path, alert: msg
        end
      end
    end
  end
end
