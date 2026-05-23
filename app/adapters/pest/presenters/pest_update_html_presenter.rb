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

          msg = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s
          if msg == I18n.t("pests.flash.reference_flag_admin_only")
            @view.redirect_to @view.pest_path(@view.params[:id]), alert: msg
            return
          end

          @view.flash.now[:alert] = msg
          payload = Domain::Pest::Dtos::PestMasterEditPayload.from_hash(@view.params[:pest].permit!.to_h.symbolize_keys)
          @view.instance_variable_set(:@pest, payload)
          request_crop_ids = @view.params[:crop_ids] ? Array(@view.params[:crop_ids]) : []
          @view.load_pest_html_crop_selection(master_edit_payload: payload, request_crop_ids: request_crop_ids)
          @view.render_form(:edit, status: :unprocessable_entity)
        end
      end
    end
  end
end
