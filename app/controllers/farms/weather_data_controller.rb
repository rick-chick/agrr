# frozen_string_literal: true

module Farms
  class WeatherDataController < ApplicationController
    # GET /farms/:farm_id/weather_data
    # パラメータ: start_date, end_date (オプション), predict (オプション)
    def index
      input_dto = Domain::WeatherData::Dtos::FarmWeatherDataJsonInputDto.new(
        farm_id: params[:farm_id].to_i,
        user_id: current_user.id,
        is_admin: admin_user?,
        predict: params[:predict] == "true",
        start_date: params[:start_date]&.to_date,
        end_date: params[:end_date]&.to_date
      )
      presenter = Presenters::Html::Farm::FarmWeatherDataJsonPresenter.new(
        view: self,
        translator: CompositionRoot.translator
      )
      CompositionRoot.farm_weather_data_json_interactor(output_port: presenter).call(input_dto)
    end

    # FarmWeatherDataJsonPresenter が参照する View インターフェース（public のままにすること）
    def render_response(json:, status:)
      render(json: json, status: status)
    end
  end
end
