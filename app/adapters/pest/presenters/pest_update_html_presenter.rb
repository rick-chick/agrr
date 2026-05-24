# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class PestUpdateHtmlPresenter < Domain::Pest::Ports::PestUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pest_entity)
          @view.redirect_to(
            @view.pest_path(pest_entity.id),
            notice: I18n.t("pests.flash.updated")
          )
        end

        def on_failure(failure_dto)
          if failure_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("pests.flash.no_permission")
            @view.redirect_to @view.pests_path
            return
          end

          if failure_dto.is_a?(Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure)
            @view.redirect_to @view.pest_path(failure_dto.resource_id), alert: failure_dto.message
            return
          end

          msg = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s

          if failure_dto.is_a?(Domain::Shared::Dtos::Error)
            @view.redirect_to @view.pests_path, alert: msg
            return
          end

          pest_id = failure_dto.is_a?(Domain::Pest::Dtos::PestMasterFormFailure) ? failure_dto.master_edit_payload.id : @view.params[:id]
          path = pest_id ? @view.pest_path(pest_id) : @view.pests_path
          @view.redirect_to path, alert: msg
        end
      end
    end
  end
end
