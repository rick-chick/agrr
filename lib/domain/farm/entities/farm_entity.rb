# frozen_string_literal: true

module Domain
  module Farm
    module Entities
      class FarmEntity
        attr_reader :id, :name, :latitude, :longitude, :region, :user_id,
                    :created_at, :updated_at, :is_reference,
                    :weather_data_status, :weather_data_fetched_years, :weather_data_total_years,
                    :weather_data_last_error

        # weather_* は HTML 詳細（気象 UI）用。一覧・API などでは nil のまま。
        def initialize(id:, name:, latitude:, longitude:, region:, user_id:,
                      created_at:, updated_at:, is_reference:,
                      weather_data_status: nil, weather_data_fetched_years: nil,
                      weather_data_total_years: nil, weather_data_last_error: nil)
          @id = id
          @name = name
          @latitude = latitude
          @longitude = longitude
          @region = region
          @user_id = user_id
          @created_at = created_at
          @updated_at = updated_at
          @is_reference = is_reference
          @weather_data_status = weather_data_status
          @weather_data_fetched_years = weather_data_fetched_years
          @weather_data_total_years = weather_data_total_years
          @weather_data_last_error = weather_data_last_error
        end

        def weather_data_progress
          total = weather_data_total_years || 0
          return 0 if total.zero?

          fetched = weather_data_fetched_years || 0
          (fetched.to_f / total * 100).round
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
