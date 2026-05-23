# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class PestDetailHtmlPresenter < Domain::Pest::Ports::PestDetailOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(pest_detail_dto)
          @view.instance_variable_set(:@pest, pest_detail_dto)
          @view.instance_variable_set(:@crops, pest_detail_dto.associated_crops)
          assign_html_display(@view, pest_detail_dto.html_display) if pest_detail_dto.html_display
          # show テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          @view.redirect_to @view.pests_path, alert: error_dto.message
        end
      end
    end
  end
end
