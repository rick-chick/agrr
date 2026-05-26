# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン保存: 参照農場に紐づくユーザー農場を取得またはコピー作成する。
      class PlanSaveEnsureUserFarmInteractor
        def initialize(plan_save_farm_gateway:, logger:, translator:, clock:)
          @gateway = plan_save_farm_gateway
          @logger = logger
          @translator = translator
          @clock = clock
        end

        # @param input_dto [Domain::CultivationPlan::Dtos::PlanSaveEnsureUserFarmInput]
        # @return [Domain::CultivationPlan::Dtos::PlanSaveEnsureUserFarmOutput]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def call(input_dto)
          farm_id = input_dto.reference_farm_id
          @logger.debug(
            @translator.t("services.plan_save_service.debug.farm_id_extracted", farm_id: farm_id)
          )

          reference_farm = @gateway.find_reference_farm(farm_id: farm_id)
          unless reference_farm
            msg = @translator.t("services.plan_save_service.errors.farm_not_found", farm_id: farm_id)
            @logger.error(msg)
            raise Domain::Shared::Exceptions::RecordNotFound, msg
          end

          @logger.debug(
            @translator.t("services.plan_save_service.debug.reference_farm_found", farm_name: reference_farm.name)
          )

          existing_farm = @gateway.find_user_farm_by_source(
            user_id: input_dto.user_id,
            source_farm_id: reference_farm.id
          )
          if existing_farm
            @logger.info("♻️ [PlanSaveService] Reusing existing farm: #{existing_farm.name}")
            return Dtos::PlanSaveEnsureUserFarmOutput.new(
              farm_id: existing_farm.id,
              farm_reused: true,
              farm_region: existing_farm.region
            )
          end

          existing_count = @gateway.count_non_reference_farms(user_id: input_dto.user_id)
          if Domain::Farm::Policies::FarmCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: existing_count
          )
            raise Domain::Shared::Exceptions::RecordInvalid,
                  @translator.t("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded")
          end

          suffix = @clock.now.strftime("%Y%m%d_%H%M%S")
          new_farm = @gateway.create_user_farm_from_reference(
            user_id: input_dto.user_id,
            reference_farm_id: reference_farm.id,
            copy_name_suffix: suffix
          )

          @logger.info(
            @translator.t("services.plan_save_service.messages.farm_created", farm_name: new_farm.name)
          )

          Dtos::PlanSaveEnsureUserFarmOutput.new(
            farm_id: new_farm.id,
            farm_reused: false,
            farm_region: new_farm.region
          )
        end
      end
    end
  end
end
