# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # 緯度経度・標高・TZ（履歴系列と予測のマージ用）。Merger への入力は primitives のみ。
      class WeatherLocationGeographyFacts
        attr_reader :latitude, :longitude, :elevation, :timezone

        def initialize(latitude:, longitude:, elevation:, timezone:)
          @latitude = latitude
          @longitude = longitude
          @elevation = elevation
          @timezone = timezone
          freeze
        end
      end
    end
  end
end
