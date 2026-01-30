# frozen_string_literal: true

module Presenters
  module Html
    module Pest
      class PestListHtmlPresenter < Domain::Pest::Ports::PestListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pests)
          # view は ActiveRecord モデルを期待するため ID から取得
          @view.instance_variable_set(:@pests, pests.map { |pe| ::Pest.find(pe.id) })
          # index テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          # リスト表示で失敗することは通常ないが、一貫性のために
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@pests, [])
        end
      end
    end
  end
end