# frozen_string_literal: true

module Presenters
  module Html
    module Pesticide
      class PesticideCreateHtmlPresenter < Domain::Pesticide::Ports::PesticideCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticide_entity)
          @view.redirect_to @view.pesticide_path(pesticide_entity.id), notice: I18n.t("pesticides.flash.created")
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.pesticides_path,
                               alert: I18n.t("pesticides.flash.no_permission")
            return
          end

          @view.flash.now[:alert] = error_dto.message
          @view.render_form(:new, status: :unprocessable_entity)
        end
      end
    end
  end
end
