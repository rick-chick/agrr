# frozen_string_literal: true

module Presenters
  module Html
    module Pesticide
      class PesticideListHtmlPresenter < Domain::Pesticide::Ports::PesticideListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticides)
          gw = Domain::Pesticide::Gateways::PesticideGateway.default
          @view.instance_variable_set(:@pesticides, pesticides.map { |p| gw.find_model(p.id) })
          # index テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          # リスト表示で失敗することは通常ないが、一貫性のために
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@pesticides, [])
        end
      end
    end
  end
end
