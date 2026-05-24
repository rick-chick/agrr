# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      class PesticideUpdateHtmlPresenter < Domain::Pesticide::Ports::PesticideUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticide_entity)
          @view.redirect_to @view.pesticide_path(pesticide_entity.id), notice: I18n.t("pesticides.flash.updated")
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.pesticides_path,
                               alert: I18n.t("pesticides.flash.no_permission")
            return
          end

          if error_dto.is_a?(Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure)
            @view.redirect_to @view.pesticide_path(error_dto.resource_id), alert: error_dto.message
            return
          end

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          pesticide_id = @view.params[:id]
          path = pesticide_id ? @view.pesticide_path(pesticide_id) : @view.pesticides_path
          @view.redirect_to path, alert: msg
        end
      end
    end
  end
end
