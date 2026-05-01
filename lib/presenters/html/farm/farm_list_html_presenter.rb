# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmListHtmlPresenter < Domain::Farm::Ports::FarmListOutputPort
        # farm_records_for_entities: Array<FarmEntity> -> Array<ActiveRecord::Farm>（コントローラで Gateway を閉じた proc を渡す）
        # reference_farms: -> Array<ActiveRecord::Farm>（管理者のみ参照農場など）
        def initialize(view:, farm_records_for_entities:, reference_farms:)
          @view = view
          @farm_records_for_entities = farm_records_for_entities
          @reference_farms = reference_farms
        end

        def on_success(farms)
          @view.instance_variable_set(:@farms, @farm_records_for_entities.call(farms))
          @view.instance_variable_set(:@reference_farms, @reference_farms.call)
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
