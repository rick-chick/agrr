# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # API 私有計画作成後の非同期ジョブチェーン起動（旧 Api::V1::PlansController#create 内のロジック）。
    class ApiPrivatePlanJobChainEnqueuer
      def initialize(logger:, clock:)
        @logger = logger
        @clock = clock
      end

      def enqueue_after_create(cultivation_plan_id:)
        cultivation_plan = ::CultivationPlan.find(cultivation_plan_id)
        farm = cultivation_plan.farm

        weather_params = weather_fetch_range(farm.weather_location)

        weather_job = FetchWeatherDataJob.new
        weather_job.latitude = farm.latitude
        weather_job.longitude = farm.longitude
        weather_job.start_date = weather_params[:start_date]
        weather_job.end_date = weather_params[:end_date]
        weather_job.farm_id = farm.id
        weather_job.cultivation_plan_id = cultivation_plan_id
        weather_job.channel_class = PlansOptimizationChannel

        prediction_job = WeatherPredictionJob.new
        prediction_job.cultivation_plan_id = cultivation_plan_id
        prediction_job.channel_class = PlansOptimizationChannel
        prediction_job.predict_days = predict_days_from(weather_params[:end_date])

        optimization_job = OptimizationJob.new
        optimization_job.cultivation_plan_id = cultivation_plan_id
        optimization_job.channel_class = PlansOptimizationChannel

        job_chain = [ weather_job, prediction_job, optimization_job ]

        crops = cultivation_plan.cultivation_plan_crops.includes(:crop).map(&:crop)
        all_crops_have_blueprints = crops.present? && crops.all? { |crop| crop.crop_task_schedule_blueprints.exists? }

        if all_crops_have_blueprints
          @logger.info("🧩 [ApiPrivatePlanJobChainEnqueuer] Blueprints found for all crops. Enqueue TaskScheduleGenerationJob.")
          task_schedule_job = TaskScheduleGenerationJob.new
          task_schedule_job.cultivation_plan_id = cultivation_plan_id
          task_schedule_job.channel_class = PlansOptimizationChannel
          job_chain << task_schedule_job
          finalize_job = PlanFinalizeJob.new
          finalize_job.cultivation_plan_id = cultivation_plan_id
          finalize_job.channel_class = PlansOptimizationChannel
          job_chain << finalize_job
        else
          @logger.info("ℹ️ [ApiPrivatePlanJobChainEnqueuer] No blueprints for some or all crops. Skipping schedule generation and finalizing plan.")
          finalize_job = PlanFinalizeJob.new
          finalize_job.cultivation_plan_id = cultivation_plan_id
          finalize_job.channel_class = PlansOptimizationChannel
          job_chain << finalize_job
        end

        chain = job_chain.map do |job|
          {
            class: job.class.name,
            args: job.job_arguments
          }
        end

        ChainedJobRunnerJob.perform_later(chain: chain, index: 0)
      end

      private

      def weather_fetch_range(location)
        today = @clock.today
        start_date = today - 20.years
        minimum_end = today - 2.days
        end_date = [ location&.latest_weather_date, minimum_end ].compact.max

        if start_date > end_date
          @logger.warn("⚠️ [ApiPrivatePlanJobChainEnqueuer] Start date (#{start_date}) is after end date (#{end_date}), adjusting...")
          end_date = start_date + 1.day
        end

        @logger.info("🌤️ [ApiPrivatePlanJobChainEnqueuer] Weather data period: #{start_date} to #{end_date}")

        {
          start_date: start_date,
          end_date: end_date
        }
      end

      def predict_days_from(end_date)
        next_year_end = Date.new(@clock.today.year + 1, 12, 31)
        predict_days = (next_year_end - end_date).to_i
        @logger.info("📅 [ApiPrivatePlanJobChainEnqueuer] Predict days: #{predict_days} (from #{end_date} to #{next_year_end})")
        predict_days
      end
    end
  end
end
