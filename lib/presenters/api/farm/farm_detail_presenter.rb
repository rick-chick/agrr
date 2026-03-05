# frozen_string_literal: true

module Presenters
  module Api
    module Farm
      class FarmDetailPresenter < Domain::Farm::Ports::FarmDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_detail_dto)
          # 成功データをコントローラーに渡す
          @view.instance_variable_set('@farm_detail_data', farm_detail_dto)
        end

        def on_failure(error_dto)
          # エラーハンドリングはコントローラーに委ねる
          # Presenter はデータを返すだけ
          @view.instance_variable_set('@farm_detail_error', error_dto)
        end

        private

        def entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            latitude: entity.latitude,
            longitude: entity.longitude,
            region: entity.region,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at,
            is_reference: entity.is_reference
          }
        end

        def field_entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            area: entity.area,
            daily_fixed_cost: entity.daily_fixed_cost,
            region: entity.region,
            farm_id: entity.farm_id,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at
          }
        end
      end
    end
  end
end
