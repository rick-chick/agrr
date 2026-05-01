# frozen_string_literal: true

module Presenters
  module Html
    module Pest
      class PestDetailHtmlPresenter < Domain::Pest::Ports::PestDetailOutputPort
        def initialize(view:, pest_model_for_detail:)
          @view = view
          @pest_model_for_detail = pest_model_for_detail
        end

        def on_success(pest_detail_dto)
          pest_model = @pest_model_for_detail.call(pest_detail_dto.pest)
          @view.instance_variable_set(:@pest, pest_model)
          @view.instance_variable_set(:@crops, pest_model.crops.recent)
          # show テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          @view.redirect_to @view.pests_path, alert: error_dto.message
        end
      end
    end
  end
end
