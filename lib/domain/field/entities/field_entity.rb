# frozen_string_literal: true

module Domain
  module Field
    module Entities
      class FieldEntity
        attr_reader :id, :farm_id, :user_id, :name, :description,
                    :created_at, :updated_at, :area, :daily_fixed_cost, :region

        def initialize(id:, farm_id:, user_id:, name:, description:,
                      created_at:, updated_at:, area:, daily_fixed_cost:, region:)
          @id = id
          @farm_id = farm_id
          @user_id = user_id
          @name = name
          @description = description
          @created_at = created_at
          @updated_at = updated_at
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          @region = region
        end

        def display_name
          name.presence || "Field #{id}"
        end

        # ActiveRecordモデルからの変換
        def self.from_model(field_model)
          new(
            id: field_model.id,
            farm_id: field_model.farm_id,
            user_id: field_model.user_id,
            name: field_model.name,
            description: field_model.description,
            created_at: field_model.created_at,
            updated_at: field_model.updated_at,
            area: field_model.area,
            daily_fixed_cost: field_model.daily_fixed_cost,
            region: field_model.region
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