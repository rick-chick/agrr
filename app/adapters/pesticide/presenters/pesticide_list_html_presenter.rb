# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      class PesticideListHtmlPresenter < Domain::Pesticide::Ports::PesticideListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticides)
          @view.instance_variable_set(:@pesticides, pesticides)
          # index テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.pesticides_path,
                               alert: I18n.t("pesticides.flash.no_permission")
            return
          end

          # リスト表示で失敗することは通常ないが、一貫性のために
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@pesticides, [])
        end
      end
    end
  end
end
