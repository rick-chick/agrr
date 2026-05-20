# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      module Html
        class PesticideDetailHtmlPresenter < Domain::Pesticide::Ports::PesticideDetailOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(pesticide_detail_dto)
            @view.instance_variable_set(:@pesticide, pesticide_detail_dto)
            # show テンプレートをレンダリング（暗黙的に）
          end

          def on_failure(error_dto)
            if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
              @view.flash[:alert] = I18n.t("pesticides.flash.no_permission")
              @view.redirect_to @view.pesticides_path
              return
            end

            @view.flash.now[:alert] = error_dto.message
            @view.redirect_to @view.pesticides_path
          end
        end
      end
    end
  end
end
