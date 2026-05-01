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
          [ latitude, longitude ]
        end

        def has_coordinates?
          Domain::Shared::ValidationHelpers.present?(latitude) && Domain::Shared::ValidationHelpers.present?(longitude)
        end

        def display_name
          name.presence || "Farm #{id}"
        end

        def as_json(options = nil)
          {
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            region: region,
            user_id: user_id,
            is_reference: is_reference,
            created_at: created_at,
            updated_at: updated_at
          }
        end

        def reference?
          is_reference
        end

        # ハッシュからの変換（テスト用）
        def self.from_hash(hash)
          new(**hash)
        end
      end
    end
  end
end
