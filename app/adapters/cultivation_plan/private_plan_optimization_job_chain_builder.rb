# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # 私有計画の最適化ジョブ列（天気取得 → 予測 → 最適化 → [スケジュール] → 確定）を組み立てる。
    # HTML（RedirectCompletion 付き）と API（チェーンのみ）の共通。
    class PrivatePlanOptimizationJobChainBuilder
      def initialize(logger:, clock:)
        @logger = logger
        @clock = clock
      end

      # @param cultivation_plan_id [Integer]
      # @param channel_class [Class]
      # @return [Array<ActiveJob::Base>]
      def build(cultivation_plan_id:, channel_class:)
        cultivation_plan = ::CultivationPlan.find(cultivation_plan_id)
        farm = cultivation_plan.farm

        weather_params = Domain::WeatherData::OptimizationJobChainWeatherComputation.weather_window(
          latest_weather_date: farm.weather_location&.latest_weather_date,
          clock: @clock
        )
        if weather_params[:range_adjusted]
          @logger.warn(
            "⚠️ [PrivatePlanOptimizationJobChainBuilder] Start date (#{weather_params[:start_date]}) is after end date before adjustment, adjusting..."
          )
        end
        start_date = weather_params[:start_date]
        end_date = weather_params[:end_date]
        @logger.info("🌤️ [PrivatePlanOptimizationJobChainBuilder] Weather data period: #{start_date} to #{end_date}")

        weather_job = FetchWeatherDataJob.new
        weather_job.latitude = farm.latitude
        weather_job.longitude = farm.longitude
        weather_job.start_date = start_date
        weather_job.end_date = end_date
        weather_job.farm_id = farm.id
        weather_job.cultivation_plan_id = cultivation_plan_id
        weather_job.channel_class = channel_class

        prediction_job = WeatherPredictionJob.new
        prediction_job.cultivation_plan_id = cultivation_plan_id
        prediction_job.channel_class = channel_class
        prediction_job.predict_days = predict_days_from(end_date)

        optimization_job = OptimizationJob.new
        optimization_job.cultivation_plan_id = cultivation_plan_id
        optimization_job.channel_class = channel_class

        job_chain = [ weather_job, prediction_job, optimization_job ]

        crops = cultivation_plan.cultivation_plan_crops.includes(:crop).map(&:crop)
        all_crops_have_blueprints = crops.present? && crops.all? { |crop| crop.crop_task_schedule_blueprints.exists? }

        if all_crops_have_blueprints
          @logger.info("🧩 [PrivatePlanOptimizationJobChainBuilder] Blueprints found for all crops. Enqueue TaskScheduleGenerationJob.")
          task_schedule_job = TaskScheduleGenerationJob.new
          task_schedule_job.cultivation_plan_id = cultivation_plan_id
          task_schedule_job.channel_class = channel_class
          job_chain << task_schedule_job
          finalize_job = PlanFinalizeJob.new
          finalize_job.cultivation_plan_id = cultivation_plan_id
          finalize_job.channel_class = channel_class
          job_chain << finalize_job
        else
          @logger.info(
            "ℹ️ [PrivatePlanOptimizationJobChainBuilder] No blueprints for some or all crops. Skipping schedule generation and finalizing plan."
          )
          finalize_job = PlanFinalizeJob.new
          finalize_job.cultivation_plan_id = cultivation_plan_id
          finalize_job.channel_class = channel_class
          job_chain << finalize_job
        end

        job_chain
      end

      private

      def predict_days_from(end_date)
        predict_days = Domain::WeatherData::OptimizationJobChainWeatherComputation.predict_days_to_next_year_end(
          end_date: end_date,
          clock: @clock
        )
        next_year_end = Date.new(@clock.today.year + 1, 12, 31)
        @logger.info(
          "📅 [PrivatePlanOptimizationJobChainBuilder] Predict days: #{predict_days} (from #{end_date} to #{next_year_end})"
        )
        predict_days
      end
    end
  end
end
