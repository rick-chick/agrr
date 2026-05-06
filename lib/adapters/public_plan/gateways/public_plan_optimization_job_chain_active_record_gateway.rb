# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Gateways
      # 公開プラン作成後の気象取得→予測→最適化→タスク生成ジョブチェーンを組み立ててエンキューする（AR / ActiveJob は本アダプタに閉じる）。
      class PublicPlanOptimizationJobChainActiveRecordGateway < Domain::PublicPlan::Gateways::PublicPlanOptimizationJobChainGateway
        def initialize(dispatcher:, logger:, channel_class:)
          @dispatcher = dispatcher
          @logger = logger
          @channel_class = channel_class
        end

        def enqueue_after_create!(cultivation_plan_id:, caller_label:)
          cultivation_plan = ::CultivationPlan.find(cultivation_plan_id)
          farm = cultivation_plan.farm

          full_weather_range = Domain::WeatherData::Policies::WeatherDataFetchWindowPolicy.fetch_range(
            latest_weather_date: farm.weather_location&.latest_weather_date,
            clock: Time.zone
          )
          if full_weather_range[:range_adjusted]
            @logger.warn "⚠️ [#{caller_label}] Start date (#{full_weather_range[:start_date]}) is after end date before adjustment, adjusting..."
          end
          weather_params = full_weather_range.except(:range_adjusted)

          end_date = weather_params[:end_date]
          predict_days = Domain::WeatherData::Policies::WeatherPredictionHorizonPolicy.predict_days_to_next_year_end(
            end_date: end_date,
            clock: Time.zone
          )

          @logger.info "🌤️ [#{caller_label}] Weather data period: #{weather_params[:start_date]} to #{end_date}"
          today = Time.zone.today
          next_year_end = Date.new(today.year + 1, 12, 31)
          @logger.info "📅 [#{caller_label}] Predict days: #{predict_days} (from #{end_date} to #{next_year_end})"

          job_instances = build_job_instances(
            cultivation_plan_id: cultivation_plan_id,
            farm: farm,
            weather_params: weather_params,
            predict_days: predict_days
          )

          @dispatcher.enqueue(job_instances, redirect_path: nil, caller_label: caller_label)
        end

        private

        def build_job_instances(cultivation_plan_id:, farm:, weather_params:, predict_days:)
          job_instances = []

          fetch_job = FetchWeatherDataJob.new
          fetch_job.farm_id = farm.id
          fetch_job.latitude = farm.latitude
          fetch_job.longitude = farm.longitude
          fetch_job.start_date = weather_params[:start_date]
          fetch_job.end_date = weather_params[:end_date]
          fetch_job.cultivation_plan_id = cultivation_plan_id
          fetch_job.channel_class = @channel_class
          job_instances << fetch_job

          prediction_job = WeatherPredictionJob.new
          prediction_job.cultivation_plan_id = cultivation_plan_id
          prediction_job.channel_class = @channel_class
          prediction_job.predict_days = predict_days
          job_instances << prediction_job

          optimization_job = OptimizationJob.new
          optimization_job.cultivation_plan_id = cultivation_plan_id
          optimization_job.channel_class = @channel_class
          job_instances << optimization_job

          task_schedule_job = TaskScheduleGenerationJob.new
          task_schedule_job.cultivation_plan_id = cultivation_plan_id
          task_schedule_job.channel_class = @channel_class
          job_instances << task_schedule_job

          job_instances
        end
      end
    end
  end
end
