# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmListHtmlPresenter < Domain::Farm::Ports::FarmListOutputPort
        def initialize(view:, is_admin:)
          @view = view
          @is_admin = is_admin
        end

        def on_success(farms)
          @view.instance_variable_set(:@farms, farms.map(&:to_model))
          if @is_admin
            @view.instance_variable_set(:@reference_farms, ::Farm.reference)
          else
            @view.instance_variable_set(:@reference_farms, [])
          end
          # index テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          # リスト表示で失敗することは通常ないが、一貫性のために
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@farms, [])
          @view.instance_variable_set(:@reference_farms, [])
        end
      end
    end
  end
end