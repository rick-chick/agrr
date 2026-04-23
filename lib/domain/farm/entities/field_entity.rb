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

        # ハッシュからの変換（テスト用）
        def self.from_hash(hash)
          new(**hash)
        end
      end
    end
  end
end
