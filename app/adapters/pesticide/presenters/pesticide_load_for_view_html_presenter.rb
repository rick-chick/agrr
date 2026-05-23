# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      # 農薬マスタの編集画面で使用する「認可付きロード」プレゼンター。
      # Domain::Pesticide::Interactors::PesticideLoadAuthorizedModelForViewInteractor と連携する。
      class PesticideLoadForViewHtmlPresenter
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(bundle)
          @view.instance_variable_set(:@pesticide, Forms::PesticideMasterForm.from_snapshot(bundle.master_form_snapshot))
          assign_html_display(@view, bundle.html_display) if bundle.html_display
        end

        def on_failure
          @view.flash[:alert] = I18n.t("pesticides.flash.not_found")
          @view.redirect_to @view.pesticides_path
        end
      end
    end
  end
end
