# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      module Html
        class PestListHtmlPresenter < Domain::Pest::Ports::PestListOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(pests)
            @view.instance_variable_set(:@pests, pests)
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
end
