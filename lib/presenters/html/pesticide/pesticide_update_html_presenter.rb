# frozen_string_literal: true

module Presenters
  module Html
    module Pesticide
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

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          if msg == I18n.t("pesticides.flash.reference_flag_admin_only")
            @view.redirect_to @view.pesticide_path(@view.params[:id]), alert: msg
            return
          end

          @view.flash.now[:alert] = msg
          @view.render_form(:edit, status: :unprocessable_entity)
        end
      end
    end
  end
end
