# frozen_string_literal: true

require_relative 'concerns/job_arguments_provider'

class FetchWeatherDataJob < ApplicationJob
  include JobArgumentsProvider
  
  queue_as :weather_data_sequential
  
  MAX_RETRY_ATTEMPTS = 5
  ALLOWED_MISSING_RATIO = 0.05
  
  # インスタンス変数の定義
  attr_accessor :latitude, :longitude, :start_date, :end_date, :farm_id, :cultivation_plan_id, :channel_class
  
  # インスタンス変数をハッシュとして返す
  def job_arguments
    {
      latitude: latitude,
      longitude: longitude,
      start_date: start_date,
      end_date: end_date,
      farm_id: farm_id,
      cultivation_plan_id: cultivation_plan_id,
      channel_class: channel_class
    }
  end

  # APIエラーやネットワークエラーに対してリトライする
  # 指数バックオフ + ジッター（ランダム性）で最大5回までリトライ
  # 基本待機時間: 3秒、9秒、27秒、81秒、243秒 + ランダム(0-50%)
  retry_on StandardError, wait: ->(executions) { 
    base_delay = 3 * (3 ** executions)
    jitter = rand(0.0..0.5) * base_delay
    (base_delay + jitter).to_i
  }, attempts: MAX_RETRY_ATTEMPTS do |job, exception|
  retry_interactor = Domain::WeatherData::Interactors::FetchWeatherDataRetryOnInteractor.new(
    farm_gateway: job.farm_gateway,
    presenter: job.presenter,
    cultivation_plan_gateway: job.cultivation_plan_gateway
  )
  retry_interactor.execute(
    input_dto: {
      farm_id: job.arguments.first[:farm_id],
      start_date: job.arguments.first[:start_date],
      end_date: job.arguments.first[:end_date],
      executions: job.executions,
      error_message: exception.message,
      cultivation_plan_id: job.arguments.first[:cultivation_plan_id],
      channel_class: job.arguments.first[:channel_class]
    }
  )
  false
  end

  # データ検証エラーなど、リトライしても意味がないエラーは即座に破棄
  discard_on ActiveRecord::RecordInvalid do |job, exception|
  discard_interactor = Domain::WeatherData::Interactors::FetchWeatherDataDiscardOnInteractor.new(
    farm_gateway: job.farm_gateway,
    presenter: job.presenter,
    cultivation_plan_gateway: job.cultivation_plan_gateway
  )
  discard_interactor.execute(
    input_dto: {
      farm_id: job.arguments.first[:farm_id],
      start_date: job.arguments.first[:start_date],
      end_date: job.arguments.first[:end_date],
      error_message: exception.message,
      cultivation_plan_id: job.arguments.first[:cultivation_plan_id],
      channel_class: job.arguments.first[:channel_class]
    }
  )
  end

  # 指定された緯度経度と期間の気象データを取得してデータベースに保存
  def perform(latitude: nil, longitude: nil, start_date: nil, end_date: nil, farm_id: nil, cultivation_plan_id: nil, channel_class: nil)
    # dictの中身を確認してバリデーション
    input_dto = {
      latitude: latitude || self.latitude,
      longitude: longitude || self.longitude,
      start_date: start_date || self.start_date,
      end_date: end_date || self.end_date,
      farm_id: farm_id || self.farm_id,
      cultivation_plan_id: cultivation_plan_id || self.cultivation_plan_id,
      channel_class: channel_class || self.channel_class,
      current_time: Time.current,
      executions: executions
    }.compact

    interactor = Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor.new(
      weather_data_gateway:,
      farm_gateway:,
      cultivation_plan_gateway:,
      agrr_weather_gateway:,
      presenter:
    )

        interactor.execute(input_dto:)

  end

    def farm_gateway
    @farm_gateway ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new
  end

  def cultivation_plan_gateway
    @cultivation_plan_gateway ||= Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new
  end

  def weather_data_gateway
    @weather_data_gateway ||= Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
  end

  def agrr_weather_gateway
    @agrr_weather_gateway ||= Agrr::WeatherGateway.new
  end

  def presenter
    @presenter ||= Adapters::WeatherData::Presenters::FetchWeatherDataJobRailsPresenter.new
  end

  private


end

