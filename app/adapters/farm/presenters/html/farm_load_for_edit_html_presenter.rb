# frozen_string_literal: true

module Adapters
  module Farm
    module Presenters
      module Html
        # 農場マスタの編集画面で使用する「認可付きロード」プレゼンター。
        # Domain::Farm::Interactors::FarmLoadAuthorizedModelForEditInteractor と連携する。
        class FarmLoadForEditHtmlPresenter
          def initialize(view:)
            @view = view
          end

          def on_success(bundle)
            @view.instance_variable_set(:@farm, Forms::FarmMasterForm.from_snapshot(bundle.master_form_snapshot))
          end

          def on_failure
            @view.flash[:alert] = I18n.t("farms.flash.not_found")
            @view.redirect_to @view.farms_path
          end
        end
      end
    end
  end
end
