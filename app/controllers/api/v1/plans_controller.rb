# frozen_string_literal: true

module Api
  module V1
    class PlansController < BaseController
      include CultivationPlanManageable
      include JobExecution
      include WeatherDataManagement
      include Views::Api::CultivationPlan::CultivationPlanDeleteView
      def index
        plans = ::CultivationPlan.plan_type_private.by_user(current_user).order(created_at: :desc)
        render json: plans.map { |plan| serialize_plan(plan) }
      end

      def show
        plan = ::CultivationPlan.plan_type_private.by_user(current_user).find(params[:id])
        render json: serialize_plan(plan)
      end

      def create
        farm = find_farm
        crops = find_crops
        plan_name = create_params[:plan_name]

        # 作物未選択のチェック
        if crops.empty?
          return render json: { error: I18n.t('plans.errors.select_crop') }, status: :unprocessable_entity
        end

        # 既存計画のチェック
        existing_plan = find_existing_plan(farm)
        if existing_plan
          return render json: { error: I18n.t('plans.errors.plan_already_exists_annual') }, status: :unprocessable_entity
        end

        # 計画作成とジョブ実行
        result = create_cultivation_plan_with_jobs(farm, crops, plan_name)
        render json: { id: result.cultivation_plan.id }, status: :created
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn "⚠️ [Api::V1::PlansController#create] Record not found: #{e.message}"
        render json: { error: I18n.t('plans.errors.not_found') }, status: :not_found
      rescue StandardError => e
        Rails.logger.error "❌ [Api::V1::PlansController#create] Unexpected error: #{e.message}"
        render json: { error: 'Internal server error' }, status: :internal_server_error
      end

      # Delete per docs/contracts/plan-delete-no-confirm-contract.md:
      # - calls the destroy interactor immediately (no confirmation dialog is necessary)
      # - renders the DeletionUndoResponse through the presenter/view contract
      def destroy
        presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: self)
        interactor = Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor.new(
          output_port: presenter,
          gateway: cultivation_plan_gateway,
          user_id: current_user.id
        )
        interactor.call(params[:id])
      end
      def render_response(json:, status:)
        render(json: json, status: status)
      end

      def undo_deletion_path(undo_token:)
        Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
      end

      private

      def serialize_plan(plan)
        {
          id: plan.id,
          name: plan.display_name,
          status: plan.status
        }
      end

      def create_params
        params.require(:plan).permit(:farm_id, :plan_name, crop_ids: [])
      end

      def find_farm
        farm_id = create_params[:farm_id]
        current_user.farms.find(farm_id)
      end

      def find_crops
        crop_ids = create_params[:crop_ids] || []
        return [] if crop_ids.empty?

        # ユーザー所有かつ非参照の作物のみ取得
        # 明示的にトップレベルの Crop を参照して、名前空間由来の解決ミスを避ける
        Domain::Shared::Policies::CropPolicy.user_owned_non_reference_scope(::Crop, current_user).where(id: crop_ids)
      end

      def find_existing_plan(farm)
        current_user.cultivation_plans
          .plan_type_private
          .where(farm: farm)
          .first
      end

      def create_cultivation_plan_with_jobs(farm, crops, plan_name = nil)
        creator_params = build_creator_params(farm, crops, plan_name)
        result = CultivationPlanCreator.new(**creator_params).call

        # エラーハンドリング
        unless result.success? && result.cultivation_plan
          Rails.logger.error "❌ [Api::V1::PlansController#create] CultivationPlan creation failed: #{result.errors.join(', ')}"
          raise ActiveRecord::RecordInvalid.new(result.cultivation_plan || ::CultivationPlan.new)
        end

        Rails.logger.info "✅ [Api::V1::PlansController#create] CultivationPlan created: #{result.cultivation_plan.id}"

        # ジョブチェーンを非同期実行
        job_instances = create_job_instances_for_api_plans(result.cultivation_plan.id)
        execute_job_chain_async(job_instances)

        result
      end

      def build_creator_params(farm, crops, plan_name)
        plan_name = plan_name.presence || farm.name
        session_id = SecureRandom.hex(16) # APIなのでセッションIDを生成

        # 通年計画: plan_yearを使わずにplanning_start_dateとplanning_end_dateを設定
        planning_start_date = Date.current.beginning_of_year
        planning_end_date = Date.new(Date.current.year + 1, 12, 31)

        {
          farm: farm,
          total_area: farm.fields.sum(:area),
          crops: crops,
          user: current_user,
          session_id: session_id,
          plan_type: 'private',
          plan_year: nil, # 通年計画
          plan_name: plan_name,
          planning_start_date: planning_start_date,
          planning_end_date: planning_end_date
        }
      end

      def create_job_instances_for_api_plans(cultivation_plan_id)
        cultivation_plan = ::CultivationPlan.find(cultivation_plan_id)
        farm = cultivation_plan.farm

        # 天気データ取得パラメータを計算
        weather_params = calculate_weather_data_params(farm.weather_location)

        # FetchWeatherDataJobのインスタンスを作成
        weather_job = FetchWeatherDataJob.new
        weather_job.latitude = farm.latitude
        weather_job.longitude = farm.longitude
        weather_job.start_date = weather_params[:start_date]
        weather_job.end_date = weather_params[:end_date]
        weather_job.farm_id = farm.id
        weather_job.cultivation_plan_id = cultivation_plan_id
        weather_job.channel_class = PlansOptimizationChannel

        # WeatherPredictionJobのインスタンスを作成
        prediction_job = WeatherPredictionJob.new
        prediction_job.cultivation_plan_id = cultivation_plan_id
        prediction_job.channel_class = PlansOptimizationChannel
        predict_days = calculate_predict_days(weather_params[:end_date])
        prediction_job.predict_days = predict_days

        # 最適化ジョブ
        optimization_job = OptimizationJob.new
        optimization_job.cultivation_plan_id = cultivation_plan_id
        optimization_job.channel_class = PlansOptimizationChannel

        # private plan の場合、blueprint が全作物に存在するときのみ作業予定生成ジョブを追加
        job_chain = [weather_job, prediction_job, optimization_job]

        crops = cultivation_plan.cultivation_plan_crops.includes(:crop).map(&:crop)
        all_crops_have_blueprints = crops.present? && crops.all? { |crop| crop.crop_task_schedule_blueprints.exists? }

        if all_crops_have_blueprints
          Rails.logger.info "🧩 [Api::V1::PlansController] Blueprints found for all crops. Enqueue TaskScheduleGenerationJob."
          task_schedule_job = TaskScheduleGenerationJob.new
          task_schedule_job.cultivation_plan_id = cultivation_plan_id
          task_schedule_job.channel_class = PlansOptimizationChannel
          job_chain << task_schedule_job
          # 作業予定生成後も最終フェーズ更新と完了を保証
          finalize_job = PlanFinalizeJob.new
          finalize_job.cultivation_plan_id = cultivation_plan_id
          finalize_job.channel_class = PlansOptimizationChannel
          job_chain << finalize_job
        else
          Rails.logger.info "ℹ️ [Api::V1::PlansController] No blueprints for some or all crops. Skipping schedule generation and finalizing plan."
          finalize_job = PlanFinalizeJob.new
          finalize_job.cultivation_plan_id = cultivation_plan_id
          finalize_job.channel_class = PlansOptimizationChannel
          job_chain << finalize_job
        end

        job_chain
      end

      def cultivation_plan_gateway
        @cultivation_plan_gateway ||= Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new
      end
    end
  end
end
