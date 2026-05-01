# frozen_string_literal: true

# Composition Root: Adapter / Port 実装の生成を一箇所に集約する。
# Controller / Job / Presenter / 他Interactor が Domain Interactor へ DI する際に利用する。
# テストでは {CompositionRoot.reset!} でメモリをクリアする。
module CompositionRoot
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

    def farm_gateway
      @farm_gateway ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new
    end

    def field_gateway
      @field_gateway ||= Adapters::Field::Gateways::FieldActiveRecordGateway.new
    end

    def crop_gateway
      @crop_gateway ||= Adapters::Crop::Gateways::CropMemoryGateway.new
    end

    def crop_stage_copy_gateway
      @crop_stage_copy_gateway ||= Adapters::Crop::Gateways::CropStageCopyActiveRecordGateway.new
    end

    def pest_gateway
      @pest_gateway ||= Adapters::Pest::Gateways::PestMemoryGateway.new
    end

    def pesticide_gateway
      @pesticide_gateway ||= Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new
    end

    def fertilize_gateway
      @fertilize_gateway ||= Adapters::Fertilize::Gateways::FertilizeActiveRecordGateway.new
    end

    def agricultural_task_gateway
      @agricultural_task_gateway ||= Adapters::AgriculturalTask::Gateways::AgriculturalTaskActiveRecordGateway.new
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

    def deletion_undo_gateway
      @deletion_undo_gateway ||= Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
    end

    def weather_data_gateway
      @weather_data_gateway ||= Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
    end

    def prediction_gateway
      @prediction_gateway ||= Adapters::WeatherData::Gateways::AgrrPredictionGatewayAdapter.new
    end

    def public_plan_save_gateway
      @public_plan_save_gateway ||= Domain::CultivationPlan::Gateways::PublicPlanSaveGateway.new
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
        cultivation_plan_gateway: cultivation_plan_gateway
      )
    end

    def weather_prediction_interactor(weather_location:, farm: nil)
      Domain::WeatherData::Interactors::WeatherPredictionInteractor.new(
        weather_location: weather_location,
        farm: farm,
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
  end
end
