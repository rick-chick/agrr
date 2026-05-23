# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # 農場一覧 HTML カード1件分。テンプレが AR に依存しないための属性（一覧 Interactor の成功データ）。
      class FarmListRow
        attr_reader :id, :display_name, :latitude, :longitude, :region, :user_id, :is_reference,
                    :field_count, :weather_data_status, :weather_data_progress,
                    :weather_data_total_years, :weather_data_last_error,
                    :created_at, :updated_at

        def initialize(id:, display_name:, latitude:, longitude:, region:, user_id:, is_reference:,
                       field_count:, weather_data_status:, weather_data_progress:,
                       weather_data_total_years:, weather_data_last_error:,
                       created_at: nil, updated_at: nil)
          @id = id
          @display_name = display_name
          @latitude = latitude
          @longitude = longitude
          @region = region
          @user_id = user_id
          @is_reference = is_reference
          @field_count = field_count
          @weather_data_status = weather_data_status
          @weather_data_progress = weather_data_progress
          @weather_data_total_years = weather_data_total_years
          @weather_data_last_error = weather_data_last_error
          @created_at = created_at
          @updated_at = updated_at
        end

        def has_coordinates?
          Domain::Shared.present?(latitude) && Domain::Shared.present?(longitude)
        end

        def fetching?
          weather_data_status == "fetching"
        end

        def failed?
          weather_data_status == "failed"
        end

        def reference?
          is_reference
        end

        def turbo_stream_subscription
          Domain::Shared::Dtos::TurboStreamSubscription.for_farm(id)
        end
      end
    end
  end
end
