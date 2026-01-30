# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmUpdateHtmlPresenter < Domain::Farm::Ports::FarmUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_entity)
          @view.redirect_to @view.farm_path(farm_entity.id), notice: I18n.t('farms.flash.updated')
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          # @farm はコントローラでセットされている前提
          @view.render_form(:edit, status: :unprocessable_entity)
        end
      end
    end
  end
end