# frozen_string_literal: true

# Composition Root: Adapter / Port 実装の生成を一箇所に集約する。
# Controller / Job / Presenter / 他Interactor が Domain Interactor へ DI する際に利用する。
# テストでは {CompositionRoot.reset!} でメモリをクリアする。
module CompositionRoot
  # API AI 用ファクトリの命名: 作物は ai_create のみのため単一アダプタ（crop_create_for_ai_adapter）。
  # 害虫・肥料は ai_update もあるため create/update ペアを返す *_ai_interactors_for。

  # API の害虫 AI 用 create/update アダプタを 1 リクエスト内でゲートウェイ共有するための戻り値型
  PestAiInteractors = Struct.new(:create_interactor, :update_interactor, keyword_init: true)
  # API の肥料 AI 用（同上）
  FertilizeAiInteractors = Struct.new(:create_interactor, :update_interactor, keyword_init: true)
  private_constant :PestAiInteractors, :FertilizeAiInteractors

  class << self
    def reset!
      instance_variables.each { |iv| remove_instance_variable(iv) }
    end

    def logger
      @logger ||= Adapters::Logger::Gateways::RailsLoggerGateway.new
    end

    def translator
      @translator ||= Adapters::Translators::RailsTranslator.new
    end

    def user_lookup
      @user_lookup ||= Adapters::Shared::Gateways::UserActiveRecordGateway.new
    end

    def deletion_undo_gateway
      @deletion_undo_gateway ||= Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
    end

    def sql_like_sanitize_port
      @sql_like_sanitize_port ||= Adapters::Shared::Gateways::SqlLikeActiveRecordGateway.new
    end

    def farm_gateway
      @farm_gateway ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new
    end

    def field_gateway
      @field_gateway ||= Adapters::Field::Gateways::FieldActiveRecordGateway.new(
        farm_gateway: farm_gateway,
        deletion_undo_gateway: deletion_undo_gateway
      )
    end

    def crop_gateway
      @crop_gateway ||= Adapters::Crop::Gateways::CropMemoryGateway.new(deletion_undo_gateway: deletion_undo_gateway)
    end

    def crop_stage_copy_gateway
      @crop_stage_copy_gateway ||= Adapters::Crop::Gateways::CropStageCopyActiveRecordGateway.new
    end

    def pest_gateway
      @pest_gateway ||= Adapters::Pest::Gateways::PestMemoryGateway.new(deletion_undo_gateway: deletion_undo_gateway)
    end

    def pesticide_gateway
      @pesticide_gateway ||= Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway
      )
    end

    def fertilize_gateway
      @fertilize_gateway ||= Adapters::Fertilize::Gateways::FertilizeActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway
      )
    end

    def agricultural_task_gateway
      @agricultural_task_gateway ||= Adapters::AgriculturalTask::Gateways::AgriculturalTaskActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway,
        sql_like_sanitize_port: sql_like_sanitize_port
      )
    end

    def task_schedule_gateway
      @task_schedule_gateway ||= Adapters::AgriculturalTask::Gateways::TaskScheduleActiveRecordGateway.new
    end

    def agrr_progress_gateway
      @agrr_progress_gateway ||= Agrr::ProgressGateway.new
    end

    def cultivation_plan_gateway
      @cultivation_plan_gateway ||= Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new
    end

    def plan_allocation_gateway
      @plan_allocation_gateway ||= Adapters::CultivationPlan::Gateways::PlanAllocationGatewayAdapter.new
    end

    def interaction_rule_gateway
      @interaction_rule_gateway ||= Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new
    end

    def weather_data_gateway
      @weather_data_gateway ||= Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
    end

    def prediction_gateway
      @prediction_gateway ||= Adapters::WeatherData::Gateways::AgrrPredictionGatewayAdapter.new
    end

    def public_plan_save_gateway
      @public_plan_save_gateway ||= Domain::CultivationPlan::Gateways::PublicPlanSaveGateway.new(
        logger: logger,
        save_from_session_runner: lambda do |user:, session_data:, logger:|
          Adapters::CultivationPlan::Sessions::PlanSaveSession.new(
            user: user,
            session_data: session_data,
            logger: logger,
            cultivation_plan_gateway: cultivation_plan_gateway,
            crop_stage_copy_gateway: crop_stage_copy_gateway
          ).call
        end
      )
    end

    def public_plan_gateway
      @public_plan_gateway ||= Adapters::PublicPlan::Gateways::PublicPlanActiveRecordGateway.new(logger: logger)
    end

    def contact_message_gateway
      @contact_message_gateway ||= Adapters::ContactMessages::Gateways::ContactMessageActiveRecordGateway.new
    end

    def agrr_adjust_gateway
      @agrr_adjust_gateway ||= Agrr::AdjustGateway.new
    end

    def agrr_candidates_gateway
      @agrr_candidates_gateway ||= Agrr::CandidatesGateway.new
    end

    # 作物 AI API は作成のみ（update 用アダプタはない）。
    def crop_create_for_ai_adapter(user_id:)
      Adapters::Crop::CropCreateForAiAdapter.new(
        user_id: user_id,
        gateway: crop_gateway,
        logger: logger,
        user_lookup: user_lookup
      )
    end

    # create / update で pest_gateway および logger 等を共有する。
    def pest_ai_interactors_for(user_id:)
      gw = pest_gateway
      log = logger
      tr = translator
      ul = user_lookup
      PestAiInteractors.new(
        create_interactor: Adapters::Pest::PestCreateForAiAdapter.new(
          user_id: user_id,
          gateway: gw,
          logger: log,
          translator: tr,
          user_lookup: ul
        ),
        update_interactor: Adapters::Pest::PestUpdateForAiAdapter.new(
          user_id: user_id,
          gateway: gw,
          logger: log,
          translator: tr,
          user_lookup: ul
        )
      )
    end

    # AI 作成・更新では FertilizeMemoryGateway を呼び出しごとに new し、1 リクエスト内の create/update で共有する。
    # プロセス全体でメモ化される `fertilize_gateway`（純 AR）とはキャッシュ方針が異なり、リクエスト間でゲートウェイ状態を持ち越さない。
    # 空名レコードを list 経路から外す従来仕様のため、純 AR ゲートウェイとは振る舞いが異なる。
    def fertilize_ai_interactors_for(user_id:)
      gw = Adapters::Fertilize::Gateways::FertilizeMemoryGateway.new(
        deletion_undo_gateway: deletion_undo_gateway
      )
      log = logger
      tr = translator
      ul = user_lookup
      FertilizeAiInteractors.new(
        create_interactor: Adapters::Fertilize::FertilizeCreateForAiAdapter.new(
          user_id: user_id,
          gateway: gw,
          logger: log,
          translator: tr,
          user_lookup: ul
        ),
        update_interactor: Adapters::Fertilize::FertilizeUpdateForAiAdapter.new(
          user_id: user_id,
          gateway: gw,
          logger: log,
          translator: tr,
          user_lookup: ul
        )
      )
    end

    def cultivation_plan_weather_dto_from(cultivation_plan)
      Domain::WeatherData::Dtos::CultivationPlanWeatherDto.new(
        id: cultivation_plan.id,
        prediction_target_end_date: cultivation_plan.prediction_target_end_date,
        calculated_planning_end_date: cultivation_plan.calculated_planning_end_date,
        predicted_weather_data: cultivation_plan.predicted_weather_data
      )
    end

    # FieldCultivation 気象 AD gateway（user DTO 単位で current_user を渡す）
    def field_cultivation_climate_gateway_for(current_user_dto)
      Adapters::FieldCultivation::Gateways::FieldCultivationClimateGateway.new(
        current_user: current_user_dto,
        logger: logger,
        translator: translator,
        progress_gateway_factory: -> { agrr_progress_gateway },
        weather_prediction_service_factory: lambda { |weather_location, farm|
          weather_prediction_interactor(weather_location: weather_location, farm: farm)
        },
        weather_data_gateway: weather_data_gateway,
        cultivation_plan_gateway: cultivation_plan_gateway,
        crop_gateway: crop_gateway,
        prediction_gateway: prediction_gateway
      )
    end

    def weather_prediction_interactor(weather_location:, farm: nil)
      wl_dto = weather_location.is_a?(Domain::WeatherData::Contracts::WeatherLocationPredictionInput) ? weather_location : weather_location_dto_from_active_record(weather_location)
      farm_dto = if farm.nil?
        nil
      elsif farm.is_a?(Domain::WeatherData::Contracts::FarmWeatherPredictionInput)
        farm
      else
        farm_weather_prediction_dto_from_active_record(farm)
      end

      Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(
        weather_location: wl_dto,
        farm: farm_dto,
        cultivation_plan_gateway: cultivation_plan_gateway,
        farm_gateway: farm_gateway,
        weather_data_gateway: weather_data_gateway,
        prediction_gateway: prediction_gateway,
        logger: logger
      )
    end

    def task_schedule_generate_interactor(clock: Time.zone)
      Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor.new(
        progress_gateway: agrr_progress_gateway,
        task_schedule_gateway: task_schedule_gateway,
        clock: clock,
        cultivation_plan_gateway: cultivation_plan_gateway
      )
    end

    private

    def weather_location_dto_from_active_record(weather_location)
      Domain::WeatherData::Dtos::WeatherLocationDto.new(
        id: weather_location.id,
        latitude: weather_location.latitude,
        longitude: weather_location.longitude,
        elevation: weather_location.elevation,
        timezone: weather_location.timezone,
        predicted_weather_data: weather_location.predicted_weather_data
      )
    end

    def farm_weather_prediction_dto_from_active_record(farm)
      Domain::WeatherData::Dtos::FarmWeatherPredictionDto.new(
        id: farm.id,
        weather_location_id: farm.weather_location_id,
        predicted_weather_data: farm.predicted_weather_data
      )
    end
  end
end
