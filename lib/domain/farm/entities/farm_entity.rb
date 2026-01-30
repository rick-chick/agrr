# frozen_string_literal: true

module Domain
  module Farm
    module Entities
      class FarmEntity
        attr_reader :id, :name, :latitude, :longitude, :region, :user_id,
                    :created_at, :updated_at, :is_reference

        def initialize(id:, name:, latitude:, longitude:, region:, user_id:,
                      created_at:, updated_at:, is_reference:)
          @id = id
          @name = name
          @latitude = latitude
          @longitude = longitude
          @region = region
          @user_id = user_id
          @created_at = created_at
          @updated_at = updated_at
          @is_reference = is_reference
        end

        def coordinates
          [latitude, longitude]
        end

        def has_coordinates?
          latitude.present? && longitude.present?
        end

        def display_name
          name.presence || "Farm #{id}"
        end

        def reference?
          is_reference
        end

        # ActiveRecordモデルからの変換
        def self.from_model(farm_model)
          new(
            id: farm_model.id,
            name: farm_model.name,
            latitude: farm_model.latitude,
            longitude: farm_model.longitude,
            region: farm_model.region,
            user_id: farm_model.user_id,
            created_at: farm_model.created_at,
            updated_at: farm_model.updated_at,
            is_reference: farm_model.is_reference
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