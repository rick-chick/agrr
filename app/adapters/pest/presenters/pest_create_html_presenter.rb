# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class PestCreateHtmlPresenter < Domain::Pest::Ports::PestCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pest_entity)
          # crop association は Interactor 内で実施済み
          @view.redirect_to(
            @view.pest_path(pest_entity.id),
            notice: I18n.t("pests.flash.created")
          )
        end

        def on_failure(failure_dto)
          if failure_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("pests.flash.no_permission")
            @view.redirect_to @view.pests_path
            return
          end

          msg = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s
          if msg == I18n.t("pests.flash.reference_only_admin")
            @view.redirect_to @view.pests_path, alert: msg
            return
          end

          @view.flash.now[:alert] = msg
          payload = Domain::Pest::Dtos::PestMasterEditPayload.from_hash(@view.params[:pest].permit!.to_h.symbolize_keys)
          @view.instance_variable_set(:@pest, payload)
          crop_ids = @view.params[:crop_ids] ? Array(@view.params[:crop_ids]) : []
          @view.prepare_crop_selection_for(payload, selected_ids: crop_ids)
          @view.render_form(:new, status: :unprocessable_entity)
        end
      end
    end
  end
end
