# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # 公開プラン保存セッション用 Farm マッパー（AR を扱うため Adapter 層）。
      class FarmMapper
        def initialize(ctx)
          @ctx = ctx
        end

        def create_or_get_user_farm
          farm_id = @ctx.session_data[:farm_id] || @ctx.session_data["farm_id"]
          Rails.logger.debug I18n.t("services.plan_save_service.debug.farm_id_extracted", farm_id: farm_id)

          reference_farm = ::Farm.find_by(id: farm_id)
          unless reference_farm
            Rails.logger.error I18n.t("services.plan_save_service.errors.farm_not_found", farm_id: farm_id)
            raise Domain::Shared::Exceptions::RecordNotFound,
                  I18n.t("services.plan_save_service.errors.farm_not_found", farm_id: farm_id)
          end
          Rails.logger.debug I18n.t("services.plan_save_service.debug.reference_farm_found", farm_name: reference_farm.name)

          existing_farm = @ctx.user.farms.find_by(source_farm_id: reference_farm.id)
          if existing_farm
            Rails.logger.info "♻️ [PlanSaveService] Reusing existing farm: #{existing_farm.name}"
            @ctx.farm_reused = true
            @ctx.result.add_skip(:farm, existing_farm.id)
            return existing_farm
          end

          existing_count = @ctx.user.farms.where(is_reference: false).count
          if Domain::Farm::Policies::FarmCreateLimitPolicy.limit_exceeded?(existing_non_reference_count: existing_count)
            raise Domain::Shared::Exceptions::RecordInvalid,
                  I18n.t("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded")
          end

          new_farm = @ctx.user.farms.build(
            name: "#{reference_farm.name} (コピー #{Time.current.strftime('%Y%m%d_%H%M%S')})",
            latitude: reference_farm.latitude,
            longitude: reference_farm.longitude,
            region: reference_farm.region,
            is_reference: false,
            weather_location_id: reference_farm.weather_location_id,
            source_farm_id: reference_farm.id
          )

          unless new_farm.save
            error_message = new_farm.errors.full_messages.join(", ")
            Rails.logger.error "❌ [PlanSaveService] Farm creation failed: #{error_message}"
            raise Domain::Shared::Exceptions::RecordInvalid, error_message
          end

          Rails.logger.info I18n.t("services.plan_save_service.messages.farm_created", farm_name: new_farm.name)
          @ctx.farm_reused = false
          new_farm
        end

        def find_existing_private_plan(farm)
          @ctx.user.cultivation_plans.where(plan_type: "private", farm: farm).first
        end
      end
    end
  end
end
