# frozen_string_literal: true

module Adapters
  module Field
    module Presenters
      # set_field 相当の失敗時、農場スコープの圃場一覧へリダイレクトする（@farm は set_farm 済み前提）。
      class FieldLoadInFarmAuthorizationFailureRedirectPresenter
        include Domain::Field::Ports::FieldLoadInFarmAuthorizationFailurePort

        def initialize(view:)
          @view = view
        end

        def on_permission_denied
          farm_id = @view.instance_variable_get(:@farm).id
          @view.redirect_to @view.farm_fields_path(farm_id), alert: I18n.t("fields.flash.no_permission")
        end

        def on_not_found
          farm_id = @view.instance_variable_get(:@farm).id
          @view.redirect_to @view.url_for(controller: "fields", action: "index", farm_id: farm_id),
                            alert: I18n.t("fields.flash.not_found")
        end
      end
    end
  end
end
