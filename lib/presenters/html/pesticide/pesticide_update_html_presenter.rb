# frozen_string_literal: true

module Presenters
  module Html
    module Pesticide
      class PesticideUpdateHtmlPresenter < Domain::Pesticide::Ports::PesticideUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticide_entity)
          @view.redirect_to @view.pesticide_path(pesticide_entity.id), notice: I18n.t('pesticides.flash.updated')
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.render_form(:edit, status: :unprocessable_entity)
        end
      end
    end
  end
end