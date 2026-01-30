# frozen_string_literal: true

module Presenters
  module Html
    module Pesticide
      class PesticideDetailHtmlPresenter < Domain::Pesticide::Ports::PesticideDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticide_detail_dto)
          @view.instance_variable_set(:@pesticide, pesticide_detail_dto.pesticide.to_model)
          # show テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.pesticides_path
        end
      end
    end
  end
end