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
      end
    end
  end
end
