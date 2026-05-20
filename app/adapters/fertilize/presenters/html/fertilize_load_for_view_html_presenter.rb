# frozen_string_literal: true

module Adapters
  module Fertilize
    module Presenters
      module Html
        class FertilizeLoadForViewHtmlPresenter < Domain::Fertilize::Ports::FertilizeLoadOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(bundle)
            @view.instance_variable_set(:@fertilize, Forms::FertilizeMasterForm.from_snapshot(bundle.master_form_snapshot))
          end

          def on_permission_denied
            @view.flash[:alert] = I18n.t("fertilizes.flash.no_permission")
            @view.redirect_to @view.fertilizes_path
          end

          def on_not_found
            @view.flash[:alert] = I18n.t("fertilizes.flash.not_found")
            @view.redirect_to @view.fertilizes_path
          end
        end
      end
    end
  end
end
