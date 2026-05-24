# frozen_string_literal: true

module Adapters
  module Farm
    module Presenters
      class FarmCreateHtmlPresenter < Domain::Farm::Ports::FarmCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_entity)
          @view.redirect_to @view.farm_path(farm_entity.id), notice: I18n.t("farms.flash.created")
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          # @farm はコントローラでセットされている前提（またはここで再構築）
          @view.redirect_to @view.farms_path, alert: error_dto.message
        end
      end
    end
  end
end
