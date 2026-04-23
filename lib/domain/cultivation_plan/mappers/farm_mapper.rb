# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class FarmMapper
        def initialize(ctx)
          @ctx = ctx
        end

        def create_or_get_user_farm
          farm_id = @ctx.session_data[:farm_id] || @ctx.session_data["farm_id"]
          Rails.logger.debug I18n.t("services.plan_save_service.debug.farm_id_extracted", farm_id: farm_id)

          reference_farm = ::Farm.find(farm_id)
          Rails.logger.debug I18n.t("services.plan_save_service.debug.reference_farm_found", farm_name: reference_farm.name)

          existing_farm = @ctx.user.farms.find_by(source_farm_id: reference_farm.id)
          if existing_farm
            Rails.logger.info "♻️ [PlanSaveService] Reusing existing farm: #{existing_farm.name}"
            @ctx.farm_reused = true
            @ctx.result.add_skip(:farm, existing_farm.id)
            return existing_farm
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
            if new_farm.errors.details[:user].any? { |e| e[:error] == :farm_limit_exceeded }
              raise StandardError, I18n.t("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded")
            end
            raise StandardError, error_message
          end

          Rails.logger.info I18n.t("services.plan_save_service.messages.farm_created", farm_name: new_farm.name)
          @ctx.farm_reused = false
          new_farm
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound => e
          Rails.logger.error I18n.t("services.plan_save_service.errors.farm_not_found", farm_id: farm_id)
          raise e
        end

        def find_existing_private_plan(farm)
          @ctx.user.cultivation_plans.where(plan_type: "private", farm: farm).first
        end
      end
    end
  end
end
