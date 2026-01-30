# frozen_string_literal: true

module Domain
  module Farm
    module Entities
      class FieldEntity
        attr_reader :id, :name, :area, :daily_fixed_cost, :region, :farm_id,
                    :user_id, :created_at, :updated_at

        def initialize(id:, name:, area:, daily_fixed_cost:, region:, farm_id:,
                      user_id:, created_at:, updated_at:)
          @id = id
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          @region = region
          @farm_id = farm_id
          @user_id = user_id
          @created_at = created_at
          @updated_at = updated_at
        end

        def display_name
          name.presence || "Field #{id}"
        end

        # ActiveRecordモデルからの変換
        def self.from_model(field_model)
          new(
            id: field_model.id,
            name: field_model.name,
            area: field_model.area,
            daily_fixed_cost: field_model.daily_fixed_cost,
            region: field_model.region,
            farm_id: field_model.farm_id,
            user_id: field_model.user_id,
            created_at: field_model.created_at,
            updated_at: field_model.updated_at
          )
        end

        # ハッシュからの変換（テスト用）
        def self.from_hash(hash)
          new(**hash)
        end
      end
    end
  end
end