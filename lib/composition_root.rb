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
      @logger ||= Adapters::Shared::Ports::RailsLoggerAdapter.new
    end

    def job_chain_async_dispatcher
      @job_chain_async_dispatcher ||= Adapters::Application::JobChainAsyncDispatcher.new(logger: logger)
    end

    def oauth_conversion_url_appender
      @oauth_conversion_url_appender ||= Adapters::Application::OauthConversionUrlAppender.new
    end

    def clock
      @clock ||= Adapters::Shared::Ports::RailsClockAdapter.new
    end

    # アプリエッジでの「今日」（テストは Time.zone 旅行と整合）
    def calendar_today
      clock.today
    end

    def translator
      @translator ||= Adapters::Shared::Ports::RailsTranslatorAdapter.new
    end

    def user_lookup
      @user_lookup ||= Adapters::Shared::Gateways::UserActiveRecordGateway.new
    end

    def auth_omniauth_session_gateway
      @auth_omniauth_session_gateway ||= Adapters::Shared::Gateways::AuthOmniauthSessionActiveRecordGateway.new
    end

    def user_session_revocation_gateway
      @user_session_revocation_gateway ||= Adapters::Shared::Gateways::UserSessionRevocationActiveRecordGateway.new
    end

    def auth_test_login_gateway
      @auth_test_login_gateway ||= Adapters::Shared::Gateways::AuthTestLoginActiveRecordGateway.new
    end

    def deletion_undo_gateway
      @deletion_undo_gateway ||= Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
    end

    def sql_like_sanitize_port
      @sql_like_sanitize_port ||= Adapters::Shared::Ports::SqlLikeActiveRecordAdapter.new
    end

    def farm_gateway
      @farm_gateway ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway
      )
    end

    def field_gateway
      @field_gateway ||= Adapters::Field::Gateways::FieldActiveRecordGateway.new(
        farm_gateway: farm_gateway,
        deletion_undo_gateway: deletion_undo_gateway,
        translator: translator
      )
    end

    def crop_gateway
      @crop_gateway ||= Adapters::Crop::Gateways::CropActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway
      )
    end

    def crop_stage_gateway
      @crop_stage_gateway ||= Adapters::Crop::Gateways::CropStageActiveRecordGateway.new
    end

    def temperature_requirement_gateway
      @temperature_requirement_gateway ||= Adapters::Crop::Gateways::TemperatureRequirementActiveRecordGateway.new
    end

    def thermal_requirement_gateway
      @thermal_requirement_gateway ||= Adapters::Crop::Gateways::ThermalRequirementActiveRecordGateway.new
    end

    def sunshine_requirement_gateway
      @sunshine_requirement_gateway ||= Adapters::Crop::Gateways::SunshineRequirementActiveRecordGateway.new
    end

    def nutrient_requirement_gateway
      @nutrient_requirement_gateway ||= Adapters::Crop::Gateways::NutrientRequirementActiveRecordGateway.new
    end

    def crop_stage_copy_interactor
      @crop_stage_copy_interactor ||= Domain::Crop::Interactors::CropStageCopyInteractor.new(
        crop_gateway: crop_gateway
      )
    end

    def crop_pest_gateway
      @crop_pest_gateway ||= Adapters::Pest::Gateways::CropPestActiveRecordGateway.new
    end

    def pest_gateway
      @pest_gateway ||= Adapters::Pest::Gateways::PestActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway
      )
    end

    def pesticide_gateway
      @pesticide_gateway ||= Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway,
        translator: translator,
        crop_gateway: crop_gateway,
        pest_gateway: pest_gateway
      )
    end

    def fertilize_gateway
      @fertilize_gateway ||= Adapters::Fertilize::Gateways::FertilizeActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway,
        translator: translator
      )
    end

    def agricultural_task_gateway
      @agricultural_task_gateway ||= Adapters::AgriculturalTask::Gateways::AgriculturalTaskActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway,
        sql_like_sanitize_port: sql_like_sanitize_port
      )
    end

    def crop_task_template_gateway
      @crop_task_template_gateway ||= Adapters::AgriculturalTask::Gateways::CropTaskTemplateActiveRecordGateway.new
    end

    def task_schedule_gateway
      @task_schedule_gateway ||= Adapters::AgriculturalTask::Gateways::TaskScheduleActiveRecordGateway.new
    end

    def agrr_progress_gateway
      @agrr_progress_gateway ||= Adapters::Agrr::Gateways::ProgressDaemonGateway.new
    end

    def crop_agrr_requirement_builder
      @crop_agrr_requirement_builder ||= Adapters::Crop::Ports::CropAgrrRequirementBuilderAdapter.new
    end

    def cultivation_plan_gateway
      @cultivation_plan_gateway ||= Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway,
        crop_agrr_requirement_builder: crop_agrr_requirement_builder
      )
    end

    def cultivation_plan_private_read_gateway
      @cultivation_plan_private_read_gateway ||=
        Adapters::CultivationPlan::Gateways::CultivationPlanPrivateReadActiveRecordGateway.new
    end

    def advance_cultivation_plan_phase_interactor
      @advance_cultivation_plan_phase_interactor ||=
        Domain::CultivationPlan::Interactors::AdvanceCultivationPlanPhaseInteractor.new(
          cultivation_plan_gateway: cultivation_plan_gateway,
          translator: translator,
          phase_broadcast_port: Adapters::CultivationPlan::Ports::CultivationPlanPhaseBroadcastAdapter.new
        )
    end

    def fetch_weather_data_enqueue_port
      @fetch_weather_data_enqueue_port ||= Adapters::WeatherData::Ports::FetchWeatherDataActiveJobAdapter.new
    end

    def start_farm_weather_data_fetch_interactor
      @start_farm_weather_data_fetch_interactor ||=
        Domain::Farm::Interactors::StartFarmWeatherDataFetchInteractor.new(
          farm_gateway: farm_gateway,
          fetch_weather_data_enqueue_port: fetch_weather_data_enqueue_port
        )
    end

    def record_farm_weather_block_completed_interactor(farm_refresh_broadcast_port: nil)
      Domain::Farm::Interactors::RecordFarmWeatherBlockCompletedInteractor.new(
        farm_gateway: farm_gateway,
        farm_refresh_broadcast_port: farm_refresh_broadcast_port ||
          Adapters::Farm::Ports::FarmRefreshBroadcastAdapter.new
      )
    end

    def mark_farm_weather_data_failed_interactor
      @mark_farm_weather_data_failed_interactor ||=
        Domain::Farm::Interactors::MarkFarmWeatherDataFailedInteractor.new(farm_gateway: farm_gateway)
    end

    def advance_cultivation_plan_phase(plan_id:, phase_name:, channel_class: nil, failure_subphase: nil)
      advance_cultivation_plan_phase_interactor.call(
        Domain::CultivationPlan::Dtos::AdvanceCultivationPlanPhaseInput.new(
          plan_id: plan_id,
          phase_name: phase_name,
          channel_class: channel_class,
          failure_subphase: failure_subphase
        )
      )
    end

    def agrr_optimization_payload_builder(cultivation_plan)
      Adapters::CultivationPlan::AgrrOptimizationPayloadBuilder.new(
        cultivation_plan,
        logger: logger,
        crop_agrr_requirement_builder: crop_agrr_requirement_builder
      )
    end

    def save_adjusted_agrr_result_gateway
      @save_adjusted_agrr_result_gateway ||= Adapters::CultivationPlan::Gateways::SaveAdjustedAgrrResultActiveRecordGateway.new(
        logger: logger,
        clock: Time.zone
      )
    end

    def save_adjusted_agrr_result_interactor
      @save_adjusted_agrr_result_interactor ||= Domain::CultivationPlan::Interactors::SaveAdjustedAgrrResultInteractor.new(
        save_gateway: save_adjusted_agrr_result_gateway,
        logger: logger
      )
    end

    def cultivation_plan_rest_optimization_events_gateway
      @cultivation_plan_rest_optimization_events_gateway ||=
        Adapters::CultivationPlan::Gateways::CultivationPlanOptimizationEventsActionCableGateway.new(
          logger: logger
        )
    end

    def cultivation_plan_rest_field_mutation_gateway
      @cultivation_plan_rest_field_mutation_gateway ||=
        Adapters::CultivationPlan::Gateways::CultivationPlanFieldMutationActiveRecordGateway.new
    end

    def cultivation_plan_rest_workbench_read_gateway
      @cultivation_plan_rest_workbench_read_gateway ||=
        Adapters::CultivationPlan::Gateways::CultivationPlanWorkbenchReadActiveRecordGateway.new
    end

    def cultivation_plan_rest_adjust_plan_growth_read_gateway
      Adapters::CultivationPlan::Gateways::CultivationPlanAdjustPlanGrowthReadActiveRecordGateway.new(
        logger: logger
      )
    end

    def cultivation_plan_rest_plan_crop_gateway
      @cultivation_plan_rest_plan_crop_gateway ||=
        Adapters::CultivationPlan::Gateways::CultivationPlanPlanCropActiveRecordGateway.new
    end

    def weather_prediction_interactor_factory
      @weather_prediction_interactor_factory ||= Adapters::WeatherData::WeatherPredictionInteractorFactory.new(
        cultivation_plan_gateway: cultivation_plan_gateway,
        farm_gateway: farm_gateway,
        weather_data_gateway: weather_data_gateway,
        prediction_gateway: prediction_gateway,
        logger: logger,
        clock: Time.zone,
        weather_location_dto_from_active_record: method(:weather_location_dto_from_active_record),
        farm_weather_prediction_dto_from_active_record: method(:farm_weather_prediction_dto_from_active_record),
        anchors_resolver_factory: lambda { |clock|
          if clock.is_a?(ActiveSupport::TimeZone)
            Adapters::WeatherData::Ports::RailsWeatherPredictionAnchorsAdapter.new(zone: clock)
          else
            raise ArgumentError,
                  "weather_prediction_interactor_factory requires ActiveSupport::TimeZone clock (#{clock.class})"
          end
        }
      )
    end

    def adjust_weather_prediction_gateway
      @adjust_weather_prediction_gateway ||= Adapters::CultivationPlan::Gateways::AdjustWeatherPredictionActiveRecordGateway.new(
        weather_prediction_interactor_factory: weather_prediction_interactor_factory
      )
    end

    def plan_allocation_adjust_interactor_factory(clock: Time.zone)
      Adapters::CultivationPlan::PlanAllocationAdjustInteractorFactory.new(
        logger: logger,
        translator: translator,
        clock: clock,
        plan_gateway: Adapters::CultivationPlan::Gateways::PlanAllocationAdjustPlanActiveRecordGateway.new(logger: logger),
        weather_prediction_gateway: adjust_weather_prediction_gateway,
        agrr_adjust_gateway: agrr_adjust_gateway,
        save_adjusted_result_interactor: save_adjusted_agrr_result_interactor,
        optimization_events_gateway: cultivation_plan_rest_optimization_events_gateway,
        adjust_plan_growth_read_gateway: cultivation_plan_rest_adjust_plan_growth_read_gateway,
        debug_dump_gateway: plan_allocation_adjust_debug_dump_gateway(clock: clock)
      )
    end

    def plan_allocation_adjust_debug_dump_gateway(clock: Time.zone)
      if Rails.env.production?
        Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway.new
      else
        Adapters::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpFileGateway.new(
          logger: logger,
          clock: clock,
          root_path: Rails.root
        )
      end
    end

    # add_crop / integration 向けレガシー Hash 戻り（adapter collector 経由）
    def plan_allocation_adjust_legacy(plan_id:, moves:, clock: Time.zone)
      collector = Adapters::CultivationPlan::Ports::PlanAllocationAdjustLegacyHashCollector.new
      plan_allocation_adjust_interactor_factory(clock: clock).build(output_port: collector).call(
        Domain::CultivationPlan::Dtos::PlanAllocationAdjustInput.new(plan_id: plan_id, moves: moves)
      )
      collector.to_h
    end

    def private_plan_optimization_job_chain_builder
      @private_plan_optimization_job_chain_builder ||= Adapters::CultivationPlan::PrivatePlanOptimizationJobChainBuilder.new(
        logger: logger,
        clock: Time.zone
      )
    end

    def api_private_plan_job_chain_enqueuer
      @api_private_plan_job_chain_enqueuer ||= Adapters::CultivationPlan::ApiPrivatePlanJobChainEnqueuer.new(
        job_chain_builder: private_plan_optimization_job_chain_builder
      )
    end

    def plan_allocation_gateway
      @plan_allocation_gateway ||= Adapters::CultivationPlan::Gateways::PlanAllocationActiveRecordGateway.new
    end

    def interaction_rule_gateway
      @interaction_rule_gateway ||= Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway,
        translator: translator
      )
    end

    def interaction_rule_agrr_format_builder
      @interaction_rule_agrr_format_builder ||=
        Adapters::InteractionRule::Ports::InteractionRuleAgrrFormatBuilderAdapter.new
    end

    def entry_schedule_optimization_gateway
      @entry_schedule_optimization_gateway ||=
        Adapters::Agrr::Gateways::EntryScheduleOptimizationDaemonGateway.new
    end

    def entry_schedule_optimize_interactor(crop:, weather_payload:, farm:, crop_gateway:)
      Domain::CultivationPlan::Interactors::EntryScheduleOptimizeInteractor.new(
        crop: crop,
        weather_payload: weather_payload,
        farm: farm,
        crop_gateway: crop_gateway,
        crop_agrr_requirement_builder: crop_agrr_requirement_builder,
        entry_schedule_optimization_gateway: entry_schedule_optimization_gateway,
        clock: clock,
        logger: logger,
        agrr_enabled: ENV["ENTRY_SCHEDULE_DISABLE_AGRR"].to_s.blank?
      )
    end

    def weather_data_gateway
      @weather_data_gateway ||= Adapters::WeatherData::WeatherDataGatewayFactory.resolve(clock: clock)
    end

    def farm_weather_prediction_payload_parse_gateway
      @farm_weather_prediction_payload_parse_gateway ||= Adapters::WeatherData::Ports::FarmWeatherPredictionPayloadParseAdapter.new
    end

    def predict_weather_standalone_enqueue_gateway
      @predict_weather_standalone_enqueue_gateway ||= Adapters::WeatherData::PredictWeatherStandaloneEnqueueActiveJobAdapter.new(
        logger: logger
      )
    end

    def farm_weather_data_access_interactor(output_port:, clock: Time.zone)
      Domain::WeatherData::Interactors::FarmWeatherDataAccessInteractor.new(
        output_port: output_port,
        farm_gateway: farm_gateway,
        weather_data_gateway: weather_data_gateway,
        enqueue_port: predict_weather_standalone_enqueue_gateway,
        prediction_payload_parse: farm_weather_prediction_payload_parse_gateway,
        logger: logger,
        clock: clock
      )
    end

    def internal_weather_fetch_start_gateway
      @internal_weather_fetch_start_gateway ||= Adapters::WeatherData::Gateways::InternalWeatherFetchStartActiveRecordGateway.new
    end

    def backdoor_application_database_clear_gateway
      @backdoor_application_database_clear_gateway ||= Adapters::Backdoor::Gateways::ApplicationDatabaseClearActiveRecordGateway.new(
        logger: logger
      )
    end

    def backdoor_shell_stdout_capture_gateway
      @backdoor_shell_stdout_capture_gateway ||= Adapters::Backdoor::Gateways::ShellStdoutCaptureCliGateway.new(logger: logger)
    end

    def session_cookie_user_gateway
      @session_cookie_user_gateway ||= Adapters::Shared::Gateways::SessionCookieUserActiveRecordGateway.new
    end

    def masters_api_session_resolve_gateway
      @masters_api_session_resolve_gateway ||= Adapters::Shared::Gateways::MastersApiSessionResolveActiveRecordGateway.new(
        session_cookie_resolver: session_cookie_user_gateway
      )
    end

    def user_api_key_rotation_gateway
      @user_api_key_rotation_gateway ||= Adapters::ApiKeys::Gateways::UserApiKeyRotationActiveRecordGateway.new
    end

    def file_blob_gateway
      @file_blob_gateway ||= Adapters::FileBlob::Gateways::FileBlobActiveRecordGateway.new(
        rails_blob_url_generator: lambda do |blob|
          Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: false)
        end
      )
    end

    def backdoor_diagnostics_gateway
      @backdoor_diagnostics_gateway ||= Adapters::Backdoor::Gateways::BackdoorDiagnosticsActiveRecordGateway.new
    end

    def scheduler_weather_update_jobs_enqueue_gateway
      @scheduler_weather_update_jobs_enqueue_gateway ||= Adapters::InternalJobs::Gateways::WeatherUpdateJobsEnqueueActiveJobGateway.new(
        logger: logger
      )
    end

    def prediction_gateway
      @prediction_gateway ||= Adapters::Agrr::Gateways::PredictionDaemonGateway.new
    end

    def public_plan_save_read_gateway
      @public_plan_save_read_gateway ||=
        Adapters::CultivationPlan::Gateways::PublicPlanSaveReadActiveRecordGateway.new
    end

    def plan_save_blueprint_copy_factory
      @plan_save_blueprint_copy_factory ||=
        Adapters::CultivationPlan::Ports::PlanSaveBlueprintCopyFactory.new(
          blueprint_gateway: crop_task_schedule_blueprint_gateway,
          logger: logger
        )
    end

    def public_plan_template_copy_gateway
      @public_plan_template_copy_gateway ||=
        Adapters::CultivationPlan::Gateways::PublicPlanTemplateCopyActiveRecordGateway.new(
          logger: logger,
          clock: clock
        )
    end

    def public_plan_save_persistence_port
      @public_plan_save_persistence_port ||=
        Adapters::CultivationPlan::Gateways::PublicPlanSavePersistenceActiveRecordAdapter.new(
          logger: logger,
          clock: clock,
          cultivation_plan_gateway: cultivation_plan_gateway,
          crop_stage_copy_interactor: crop_stage_copy_interactor,
          blueprint_copy_factory: plan_save_blueprint_copy_factory,
          template_copy_gateway: public_plan_template_copy_gateway
        )
    end

    def plan_copy_gateway
      @plan_copy_gateway ||= Adapters::CultivationPlan::Gateways::PlanCopyActiveRecordGateway.new
    end

    def crop_task_schedule_blueprint_gateway
      @crop_task_schedule_blueprint_gateway ||=
        Adapters::CultivationPlan::Gateways::CropTaskScheduleBlueprintActiveRecordGateway.new
    end

    def cultivation_plan_plan_initializer
      lambda do |**kwargs|
        Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor.new(
          cultivation_plan_gateway: cultivation_plan_gateway,
          plan_crop_gateway: cultivation_plan_rest_plan_crop_gateway,
          field_mutation_gateway: cultivation_plan_rest_field_mutation_gateway,
          clock: clock,
          logger: logger,
          **kwargs
        ).call
      end
    end

    def plan_copy_interactor
      Domain::CultivationPlan::Interactors::PlanCopyInteractor.new(
        plan_copy_gateway: plan_copy_gateway,
        logger: logger
      )
    end

    def public_plan_gateway
      @public_plan_gateway ||= Adapters::PublicPlan::Gateways::PublicPlanActiveRecordGateway.new
    end

    def public_plan_optimization_job_chain_gateway
      @public_plan_optimization_job_chain_gateway ||= Adapters::PublicPlan::Gateways::PublicPlanOptimizationJobChainActiveRecordGateway.new(
        dispatcher: job_chain_async_dispatcher,
        logger: logger,
        channel_class: ::OptimizationChannel
      )
    end

    def contact_message_gateway
      @contact_message_gateway ||= Adapters::ContactMessages::Gateways::ContactMessageActiveRecordGateway.new
    end

    def agrr_adjust_gateway
      @agrr_adjust_gateway ||= Adapters::CultivationPlan::Gateways::PlanAdjustActiveRecordGateway.new
    end

    def agrr_candidates_gateway
      @agrr_candidates_gateway ||= Adapters::Agrr::Gateways::CandidatesDaemonGateway.new
    end

    # add_crop 候補探索（Api::V1::CultivationPlanRestBaseController 経路の主導線）
    def find_best_add_crop_candidate_interactor(clock: Time.zone)
      @find_best_add_crop_candidate_interactor_cache ||= {}
      @find_best_add_crop_candidate_interactor_cache[clock] ||= build_find_best_add_crop_candidate_interactor(clock: clock)
    end

    def find_best_add_crop_candidate_service(clock: Time.zone)
      find_best_add_crop_candidate_interactor(clock: clock)
    end

    def build_find_best_add_crop_candidate_interactor(clock: Time.zone)
      log = logger
      gw = agrr_candidates_gateway

      plan_loader = lambda do |auth:, plan_id:|
        ::Adapters::CultivationPlan::Persistence::PlanScopes.find_record!(auth, plan_id)
      end

      allocation_configs = lambda do |plan|
        b = agrr_optimization_payload_builder(plan)
        {
          current_allocation: b.build_current_allocation(exclude_ids: []),
          fields: b.build_fields_config,
          crops: b.build_crops_config,
          interaction_rules: b.build_interaction_rules
        }
      end

      weather_for_candidates = lambda do |weather_location:, farm:, cultivation_plan:, target_end_date:|
        wp = weather_prediction_interactor(weather_location: weather_location, farm: farm, clock: clock)
        log.info "🔍 [Candidates] Weather target end date: #{target_end_date || 'N/A'}"
        existing = wp.get_existing_prediction(
          target_end_date: target_end_date,
          cultivation_plan_weather: cultivation_plan_weather_dto_from(cultivation_plan)
        )

        weather_prediction_status = nil
        weather_data = nil
        if existing
          weather_prediction_status = "cache_hit"
          log.info "📡 [Candidates] Domain::WeatherData::Interactors::WeatherPredictionInteractor cache hit (target_end_date=#{target_end_date || 'N/A'})"
          weather_data = existing[:data]
        else
          weather_prediction_status = "requesting_prediction"
          log.info "📡 [Candidates] Domain::WeatherData::Interactors::WeatherPredictionInteractor cache miss - invoking prediction (target_end_date=#{target_end_date || 'N/A'})"
          weather_info = wp.predict_for_cultivation_plan(
            plan_weather: cultivation_plan_weather_dto_from(cultivation_plan),
            target_end_date: target_end_date
          )
          weather_data = weather_info[:data]
        end

        if weather_data.is_a?(Hash) && weather_data["data"].is_a?(Hash) && weather_data["data"]["data"].is_a?(Array)
          weather_data = weather_data["data"]
        end

        data_days = weather_data.is_a?(Hash) ? Array(weather_data["data"]).count : 0
        log.info "📡 [Candidates] Domain::WeatherData::Interactors::WeatherPredictionInteractor result: status=#{weather_prediction_status} days=#{data_days}"
        weather_data
      rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
             Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
        log.warn "⚠️ [Candidates] Weather prediction error: #{e.message}"
        raise
      rescue ActiveRecord::ActiveRecordError \
             , Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError \
             , Adapters::Agrr::Gateways::BaseGatewayV2::ParseError \
             , ::Adapters::Agrr::Gateways::DaemonClient::AgrrError \
             , JSON::ParserError \
             , JSON::GeneratorError \
             , SystemCallError \
             , IOError \
             , SocketError => e
        log.error "❌ [Candidates] Failed to get weather data: #{e.message}"
        nil
      end

      candidates_invoker = lambda do |current_allocation:, fields:, crops:, crop:, weather_data:, planning_start:, planning_end:, interaction_rules:|
        interactor = Domain::CultivationPlan::Interactors::AgrrCandidatesInteractor.new(
          gateway: gw,
          logger: log
        )
        ir = interaction_rules.empty? ? nil : interaction_rules
        interactor.call(
          current_allocation: current_allocation,
          fields: fields,
          crops: crops,
          target_crop_id: crop.id,
          weather_data: weather_data,
          planning_start: planning_start,
          planning_end: planning_end,
          interaction_rules: ir
        )
      rescue Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError,
             Adapters::Agrr::Gateways::BaseGatewayV2::ParseError,
             Adapters::Agrr::Gateways::BaseGatewayV2::NoAllocationCandidatesError,
             JSON::ParserError,
             SystemCallError => e
        log.error "❌ [Candidates] Failed to run candidates: #{e.message}"
        []
      end

      Domain::CultivationPlan::Interactors::FindBestAddCropCandidateInteractor.new(
        logger: log,
        today: -> { clock.today },
        plan_loader: plan_loader,
        allocation_configs: allocation_configs,
        weather_for_candidates: weather_for_candidates,
        candidates_invoker: candidates_invoker
      )
    end

    # 作物 AI API は作成のみ（update 用アダプタはない）。
    def crop_create_for_ai_adapter(user_id:)
      Adapters::Crop::CropCreateForAiAdapter.new(
        user_id: user_id,
        gateway: crop_gateway,
        translator: translator,
        user_lookup: user_lookup
      )
    end

    def crop_ai_create_interactor(current_user:, output_port:)
      uid = current_user.id
      Domain::Crop::Interactors::CropAiCreateInteractor.new(
        output_port: output_port,
        user_id: uid,
        user_lookup: user_lookup,
        translator: translator,
        logger: logger,
        crop_ai_query_gateway: crop_ai_daemon_query_gateway,
        persistence: Adapters::Crop::CropAiUpsertActiveRecordPersistence.new(
          crop_gateway: crop_gateway,
          create_interactor: crop_create_for_ai_adapter(user_id: uid),
          logger: logger,
          translator: translator
        )
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
          crop_gateway: crop_gateway,
          crop_pest_gateway: crop_pest_gateway,
          translator: tr,
          user_lookup: ul
        ),
        update_interactor: Adapters::Pest::PestUpdateForAiAdapter.new(
          user_id: user_id,
          gateway: gw,
          crop_gateway: crop_gateway,
          crop_pest_gateway: crop_pest_gateway,
          logger: log,
          translator: tr,
          user_lookup: ul
        )
      )
    end

    # AI 作成・更新では FertilizeAiActiveRecordGateway を呼び出しごとに new し、1 リクエスト内の create/update で共有する。
    # プロセス全体でメモ化される `fertilize_gateway` とはキャッシュ方針が異なり、リクエスト間でゲートウェイ状態を持ち越さない。
    # 空名レコードを list 経路から外す従来仕様のため、通常の FertilizeActiveRecordGateway とは振る舞いが異なる。
    def fertilize_ai_interactors_for(user_id:)
      gw = Adapters::Fertilize::Gateways::FertilizeAiActiveRecordGateway.new(
        deletion_undo_gateway: deletion_undo_gateway,
        translator: translator
      )
      tr = translator
      ul = user_lookup
      FertilizeAiInteractors.new(
        create_interactor: Adapters::Fertilize::FertilizeCreateForAiAdapter.new(
          user_id: user_id,
          gateway: gw,
          translator: tr,
          user_lookup: ul
        ),
        update_interactor: Adapters::Fertilize::FertilizeUpdateForAiAdapter.new(
          user_id: user_id,
          gateway: gw,
          translator: tr,
          user_lookup: ul
        )
      )
    end

    def cultivation_plan_weather_dto_from(cultivation_plan)
      Domain::WeatherData::Dtos::CultivationPlanWeather.new(
        id: cultivation_plan.id,
        prediction_target_end_date: cultivation_plan.prediction_target_end_date,
        calculated_planning_end_date: cultivation_plan.calculated_planning_end_date,
        predicted_weather_data: cultivation_plan.predicted_weather_data
      )
    end

    # FieldCultivation API 用ファサード（認可・CRUD）
    def field_cultivation_climate_gateway_for(current_user_dto)
      Adapters::FieldCultivation::Gateways::FieldCultivationClimateActiveRecordGateway.new(
        context_gateway: field_cultivation_climate_source_gateway_for(current_user_dto)
      )
    end

    def field_cultivation_climate_source_gateway_for(_current_user_dto = nil)
      @field_cultivation_climate_source_gateway ||= Adapters::FieldCultivation::Gateways::FieldCultivationClimateSourceActiveRecordGateway.new
    end

    def field_cultivation_climate_progress_gateway
      if Rails.env.test?
        @field_cultivation_climate_progress_memory_gateway ||=
          Adapters::FieldCultivation::Gateways::FieldCultivationClimateProgressMemoryGateway.new(logger: logger)
      else
        @field_cultivation_climate_progress_active_record_gateway ||=
          Adapters::FieldCultivation::Gateways::FieldCultivationClimateProgressActiveRecordGateway.new(
            progress_gateway_factory: -> { agrr_progress_gateway }
          )
      end
    end

    def field_cultivation_climate_data_interactor(output_port:, user_dto:)
      clock = Time.zone
      anchors_resolver = Adapters::WeatherData::Ports::RailsWeatherPredictionAnchorsAdapter.new(zone: clock)
      Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor.new(
        output_port: output_port,
        logger: logger,
        user_id: user_dto&.id,
        user_lookup: user_lookup,
        climate_source_gateway: field_cultivation_climate_source_gateway_for,
        crop_gateway: crop_gateway,
        weather_data_gateway: weather_data_gateway,
        weather_prediction_gateway: adjust_weather_prediction_gateway,
        prediction_gateway: prediction_gateway,
        cultivation_plan_gateway: cultivation_plan_gateway,
        anchors_resolver: anchors_resolver,
        climate_progress_gateway: field_cultivation_climate_progress_gateway,
        clock: clock,
        translator: translator
      )
    end

    def weather_prediction_interactor(weather_location:, farm: nil, clock: Time.zone, anchors_resolver: nil)
      wl_dto = weather_location.is_a?(Domain::WeatherData::Contracts::WeatherLocationPredictionInput) ? weather_location : weather_location_dto_from_active_record(weather_location)
      farm_dto = if farm.nil?
        nil
      elsif farm.is_a?(Domain::WeatherData::Contracts::FarmWeatherPredictionInput)
        farm
      else
        farm_weather_prediction_dto_from_active_record(farm)
      end

      anchors_resolver ||= if clock.is_a?(ActiveSupport::TimeZone)
        Adapters::WeatherData::Ports::RailsWeatherPredictionAnchorsAdapter.new(zone: clock)
      else
        raise ArgumentError,
              "weather_prediction_interactor requires anchors_resolver when clock is not an ActiveSupport::TimeZone (#{clock.class})"
      end
      Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(
        weather_location: wl_dto,
        farm: farm_dto,
        cultivation_plan_gateway: cultivation_plan_gateway,
        farm_gateway: farm_gateway,
        weather_data_gateway: weather_data_gateway,
        prediction_gateway: prediction_gateway,
        logger: logger,
        clock: clock,
        anchors_resolver: anchors_resolver
      )
    end

    def entry_schedule_weather_loader_adapter
      @entry_schedule_weather_loader_adapter ||= Adapters::PublicPlan::EntryScheduleWeatherLoaderAdapter.new(
        prediction_service_factory: lambda { |farm|
          weather_prediction_interactor(weather_location: farm.weather_location, farm: farm)
        }
      )
    end

    def entry_schedule_cursor_decoder
      @entry_schedule_cursor_decoder ||= Adapters::PublicPlan::EntryScheduleCursorDecoder.new
    end

    def entry_schedule_reference_farm_loader
      @entry_schedule_reference_farm_loader ||= lambda do |farm_id|
        raise Domain::Shared::Exceptions::RecordNotFound, "farm_id is required" if farm_id.blank?

        farm = ::Farm.find(farm_id)
        raise Domain::Shared::Exceptions::RecordNotFound, "not a reference farm" unless farm.reference?

        farm
      rescue ActiveRecord::RecordNotFound => e
        raise Domain::Shared::Exceptions::RecordNotFound, e.message
      end
    end

    def entry_schedule_resolve_reference_farm_interactor(output_port:)
      Domain::PublicPlan::Interactors::EntryScheduleResolveReferenceFarmInteractor.new(
        output_port: output_port,
        farm_loader: entry_schedule_reference_farm_loader
      )
    end

    def entry_schedule_crops_index_interactor(output_port:)
      Domain::PublicPlan::Interactors::EntryScheduleCropsIndexInteractor.new(
        output_port: output_port,
        weather_loader: entry_schedule_weather_loader_adapter,
        crop_gateway: crop_gateway,
        optimization_runner: Adapters::PublicPlan::EntryScheduleOptimizationRunnerAdapter,
        translator: translator,
        clock: Time.zone,
        logger: logger
      )
    end

    def entry_schedule_show_interactor(output_port:, clock: Time.zone)
      Domain::PublicPlan::Interactors::EntryScheduleShowInteractor.new(
        output_port: output_port,
        crop_gateway: crop_gateway,
        weather_loader: entry_schedule_weather_loader_adapter,
        optimization_runner: Adapters::PublicPlan::EntryScheduleOptimizationRunnerAdapter,
        translator: translator,
        clock: clock
      )
    end

    def task_schedule_item_mutation_gateway
      @task_schedule_item_mutation_gateway ||= Adapters::CultivationPlan::Gateways::TaskScheduleItemMutationActiveRecordGateway.new(
        logger: logger
      )
    end

    def task_schedule_item_create_interactor(output_port:)
      Domain::CultivationPlan::Interactors::TaskScheduleItemCreateInteractor.new(
        output_port: output_port,
        gateway: task_schedule_item_mutation_gateway
      )
    end

    def task_schedule_item_update_interactor(output_port:)
      Domain::CultivationPlan::Interactors::TaskScheduleItemUpdateInteractor.new(
        output_port: output_port,
        gateway: task_schedule_item_mutation_gateway,
        clock: Time.zone
      )
    end

    def task_schedule_item_complete_interactor(output_port:)
      Domain::CultivationPlan::Interactors::TaskScheduleItemCompleteInteractor.new(
        output_port: output_port,
        gateway: task_schedule_item_mutation_gateway,
        clock: Time.zone
      )
    end

    def deletion_undo_schedule_interactor(output_port:)
      Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor.new(
        output_port: output_port,
        gateway: deletion_undo_gateway,
        user_lookup: user_lookup
      )
    end

    def task_schedule_item_schedule_deletion_undo_interactor(mutation_output_port:, undo_output_port:, translator:)
      Domain::CultivationPlan::Interactors::TaskScheduleItemScheduleDeletionUndoInteractor.new(
        mutation_output_port: mutation_output_port,
        mutation_gateway: task_schedule_item_mutation_gateway,
        deletion_undo_interactor: deletion_undo_schedule_interactor(output_port: undo_output_port),
        translator: translator
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

    def crop_ai_daemon_query_gateway
      @crop_ai_daemon_query_gateway ||= Adapters::Agrr::Gateways::CropAiQueryDaemonGateway.new(
        logger: logger,
        translator: translator
      )
    end

    def pest_ai_daemon_query_gateway
      @pest_ai_daemon_query_gateway ||= Adapters::Agrr::Gateways::PestAiQueryDaemonGateway.new(
        logger: logger,
        translator: translator
      )
    end

    def fertilize_ai_query_gateway
      @fertilize_ai_query_gateway ||= Adapters::Fertilize::FertilizeAiGatewayResolver.new(
        config_gateway: Rails.configuration.x.fertilize_ai_gateway
      ).resolve
    end

    def pest_ai_create_interactor(current_user:, output_port:)
      uid = current_user.id
      pair = pest_ai_interactors_for(user_id: uid)
      gw = pest_gateway
      log = logger
      Domain::Pest::Interactors::PestAiCreateInteractor.new(
        output_port: output_port,
        user_id: uid,
        user_lookup: user_lookup,
        pest_gateway: gw,
        pest_ai_query_gateway: pest_ai_daemon_query_gateway,
        create_interactor: pair.create_interactor,
        update_interactor: pair.update_interactor,
        logger: log,
        translator: translator,
        associate_affected_crops_runner: lambda { |pest_id, crops|
          Domain::Pest::Interactors::PestAssociateAffectedCropsInteractor.new(
            user_id: uid,
            user_lookup: user_lookup,
            pest_gateway: gw,
            crop_gateway: crop_gateway,
            crop_pest_gateway: crop_pest_gateway,
            logger: log
          ).call(pest_id: pest_id, affected_crops: crops)
        }
      )
    end

    def pest_ai_update_interactor(current_user:)
      uid = current_user.id
      pair = pest_ai_interactors_for(user_id: uid)
      Domain::Pest::Interactors::PestAiUpdateInteractor.new(
        user_id: uid,
        user_lookup: user_lookup,
        pest_gateway: pest_gateway,
        pest_ai_query_gateway: pest_ai_daemon_query_gateway,
        update_interactor: pair.update_interactor,
        logger: logger,
        translator: translator
      )
    end

    def fertilize_ai_create_interactor(current_user:, output_port:)
      uid = current_user.id
      pair = fertilize_ai_interactors_for(user_id: uid)
      Domain::Fertilize::Interactors::FertilizeAiCreateInteractor.new(
        output_port: output_port,
        user_id: uid,
        user_lookup: user_lookup,
        fertilize_gateway: fertilize_gateway,
        fertilize_ai_query_gateway: fertilize_ai_query_gateway,
        create_interactor: pair.create_interactor,
        update_interactor: pair.update_interactor,
        logger: logger,
        translator: translator
      )
    end

    def fertilize_ai_update_interactor(current_user:)
      uid = current_user.id
      pair = fertilize_ai_interactors_for(user_id: uid)
      Domain::Fertilize::Interactors::FertilizeAiUpdateInteractor.new(
        user_id: uid,
        user_lookup: user_lookup,
        fertilize_gateway: fertilize_gateway,
        fertilize_ai_query_gateway: fertilize_ai_query_gateway,
        update_interactor: pair.update_interactor,
        logger: logger,
        translator: translator
      )
    end

    private

    def weather_location_dto_from_active_record(weather_location)
      Domain::WeatherData::Dtos::WeatherLocation.new(
        id: weather_location.id,
        latitude: weather_location.latitude,
        longitude: weather_location.longitude,
        elevation: weather_location.elevation,
        timezone: weather_location.timezone,
        predicted_weather_data: weather_location.predicted_weather_data
      )
    end

    def farm_weather_prediction_dto_from_active_record(farm)
      Domain::WeatherData::Dtos::FarmWeatherPrediction.new(
        id: farm.id,
        weather_location_id: farm.weather_location_id,
        predicted_weather_data: farm.predicted_weather_data
      )
    end
  end
end
