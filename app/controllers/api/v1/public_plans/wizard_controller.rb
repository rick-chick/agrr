# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class WizardController < ApplicationController
        include JobExecution
        include WeatherDataManagement

        skip_before_action :authenticate_user!
        skip_before_action :verify_authenticity_token

        def farms
          region = params[:region].presence || locale_to_region(I18n.locale)
          farms = Domain::Shared::Policies::FarmPolicy.reference_scope(Farm, region: region)
          render json: farms
        end

        def farm_sizes
          render json: farm_sizes_with_i18n
        end

        def crops
          Rails.logger.info "🌱 [WizardController#crops] Called with farm_id: #{params[:farm_id]}"
          farm = Farm.find(params[:farm_id])
          Rails.logger.info "🌱 [WizardController#crops] Found farm: #{farm.id}, region: #{farm.region}"
          crops = Domain::Shared::Policies::CropPolicy.reference_scope(::Crop, region: farm.region).order(:name)
          Rails.logger.info "🌱 [WizardController#crops] Found #{crops.count} crops"
          render json: crops
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.warn "❌ [WizardController#crops] Farm not found: #{params[:farm_id]} - #{e.message}"
          render json: { error: 'Farm not found' }, status: :not_found
        rescue => e
          Rails.logger.error "❌ [WizardController#crops] Unexpected error: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: 'Internal server error' }, status: :internal_server_error
        end

        def create
          Rails.logger.info "🌱 [WizardController#create] Called with farm_id: #{params[:farm_id]}, farm_size_id: #{params[:farm_size_id]}, crop_ids: #{params[:crop_ids]}"

          farm = Farm.find(params[:farm_id])
          Rails.logger.info "🌱 [WizardController#create] Found farm: #{farm.id}"

          farm_size = find_farm_size(params[:farm_size_id])
          unless farm_size
            Rails.logger.warn "❌ [WizardController#create] Invalid farm_size_id: #{params[:farm_size_id]}"
            return render json: { error: I18n.t('public_plans.errors.select_farm_size') }, status: :unprocessable_entity
          end

          total_area = farm_size[:area_sqm]
          unless total_area.positive?
            Rails.logger.warn "❌ [WizardController#create] Invalid total_area: #{total_area}"
            return render json: { error: I18n.t('public_plans.errors.invalid_farm_size') }, status: :unprocessable_entity
          end

          crops = ::Crop.where(id: crop_ids)
          Rails.logger.info "🌱 [WizardController#create] Found #{crops.count} crops for ids: #{crop_ids}"
          if crops.empty?
            Rails.logger.warn "❌ [WizardController#create] No crops found for ids: #{crop_ids}"
            return render json: { error: I18n.t('public_plans.errors.select_crop') }, status: :unprocessable_entity
          end

          creator_params = {
            farm: farm,
            total_area: total_area,
            crops: crops,
            user: current_user,
            session_id: session.id.to_s,
            plan_type: 'public',
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          }

          Rails.logger.info "🌱 [WizardController#create] Creating cultivation plan with params: #{creator_params.except(:farm, :crops, :user)}"
          result = CultivationPlanCreator.new(**creator_params).call
          unless result.success?
            Rails.logger.warn "❌ [WizardController#create] CultivationPlanCreator failed: #{result.errors.join(', ')}"
            return render json: { error: result.errors.join(', ') }, status: :unprocessable_entity
          end

          cultivation_plan = result.cultivation_plan
          Rails.logger.info "🌱 [WizardController#create] Created cultivation plan: #{cultivation_plan.id}"

          job_instances = create_job_instances_for_public_plans(cultivation_plan.id, OptimizationChannel)
          execute_job_chain_async(job_instances)

          render json: { plan_id: cultivation_plan.id }
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.warn "❌ [WizardController#create] Record not found: #{e.message}"
          render json: { error: 'Record not found' }, status: :not_found
        rescue => e
          Rails.logger.error "❌ [WizardController#create] Unexpected error: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: 'Internal server error' }, status: :internal_server_error
        end

        private

        def farm_sizes_with_i18n
          base_farm_sizes.map do |size|
            size.merge(
              name: I18n.t("public_plans.farm_sizes.#{size[:id]}.name"),
              description: I18n.t("public_plans.farm_sizes.#{size[:id]}.description")
            )
          end
        end

        def base_farm_sizes
          [
            { id: 'home_garden', area_sqm: 30 },
            { id: 'community_garden', area_sqm: 50 },
            { id: 'rental_farm', area_sqm: 300 }
          ]
        end

        # id（文字列）または area_sqm（Integer）で一致させる。フロントが number で送っても 422 にしない。
        def find_farm_size(param)
          return nil if param.blank?

          farm_sizes_with_i18n.find do |size|
            size[:id].to_s == param.to_s || size[:area_sqm] == param.to_i
          end
        end

        def crop_ids
          ids = params[:crop_ids].presence || []
          ids.is_a?(Array) ? ids : Array(ids)
        end

        def locale_to_region(locale)
          case locale.to_s
          when 'ja'
            'jp'
          when 'us'
            'us'
          when 'in'
            'in'
          else
            'jp'
          end
        end

        def create_job_instances_for_public_plans(cultivation_plan_id, channel_class)
          cultivation_plan = ::CultivationPlan.find(cultivation_plan_id)
          farm = cultivation_plan.farm

          weather_params = calculate_weather_data_params(farm.weather_location)
          predict_days = calculate_predict_days(weather_params[:end_date])

          job_instances = []

          fetch_job = FetchWeatherDataJob.new
          fetch_job.farm_id = farm.id
          fetch_job.latitude = farm.latitude
          fetch_job.longitude = farm.longitude
          fetch_job.start_date = weather_params[:start_date]
          fetch_job.end_date = weather_params[:end_date]
          fetch_job.cultivation_plan_id = cultivation_plan_id
          fetch_job.channel_class = channel_class
          job_instances << fetch_job

          prediction_job = WeatherPredictionJob.new
          prediction_job.cultivation_plan_id = cultivation_plan_id
          prediction_job.channel_class = channel_class
          prediction_job.predict_days = predict_days
          job_instances << prediction_job

          optimization_job = OptimizationJob.new
          optimization_job.cultivation_plan_id = cultivation_plan_id
          optimization_job.channel_class = channel_class
          job_instances << optimization_job

          task_schedule_job = TaskScheduleGenerationJob.new
          task_schedule_job.cultivation_plan_id = cultivation_plan_id
          task_schedule_job.channel_class = channel_class
          job_instances << task_schedule_job

          job_instances
        end
      end
    end
  end
end
