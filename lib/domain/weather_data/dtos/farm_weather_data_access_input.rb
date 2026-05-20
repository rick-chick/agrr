# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # Controller エッジで params を意味のある値にした後だけ Interactor に渡す。
      class FarmWeatherDataAccessInput
        attr_reader :farm_id, :user_id, :is_admin, :predict, :start_date, :end_date

        def initialize(farm_id:, user_id:, is_admin:, predict:, start_date: nil, end_date: nil)
          @farm_id = farm_id
          @user_id = user_id
          @is_admin = is_admin
          @predict = predict
          @start_date = start_date
          @end_date = end_date
        end
      end
    end
  end
end
