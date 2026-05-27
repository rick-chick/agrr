# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveFarmActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanSaveFarmGateway
        def find_reference_farm(farm_id:)
          record = ::Farm.find_by(id: farm_id)
          return nil unless record

          reference_farm_snapshot(record)
        end

        def find_user_farm_by_source(user_id:, source_farm_id:)
          record = ::Farm.find_by(user_id: user_id, source_farm_id: source_farm_id)
          return nil unless record

          user_farm_snapshot(record)
        end

        def count_non_reference_farms(user_id:)
          ::Farm.where(user_id: user_id, is_reference: false).count
        end

        def create_user_farm_from_reference(user_id:, reference_farm_id:, copy_name_suffix:)
          reference = ::Farm.find_by(id: reference_farm_id)
          unless reference
            raise Domain::Shared::Exceptions::RecordNotFound,
                  I18n.t("services.plan_save_service.errors.farm_not_found", farm_id: reference_farm_id)
          end

          user = ::User.find_by(id: user_id)
          unless user
            raise Domain::Shared::Exceptions::RecordNotFound, "User not found: #{user_id}"
          end

          new_farm = user.farms.build(
            name: "#{reference.name} (コピー #{copy_name_suffix})",
            latitude: reference.latitude,
            longitude: reference.longitude,
            region: reference.region,
            is_reference: false,
            weather_location_id: reference.weather_location_id,
            source_farm_id: reference.id
          )

          unless new_farm.save
            raise Domain::Shared::Exceptions::RecordInvalid, new_farm.errors.full_messages.join(", ")
          end

          user_farm_snapshot(new_farm)
        end

        def find_owned_farm_record(user_id:, farm_id:)
          ::Farm.find_by(id: farm_id, user_id: user_id)
        end

        def find_owned_private_plan_record(user_id:, farm_id:)
          ::CultivationPlan.find_by(plan_type: "private", farm_id: farm_id, user_id: user_id)
        end

        private

        def reference_farm_snapshot(record)
          Domain::CultivationPlan::Dtos::PlanSaveReferenceFarmSnapshot.new(
            id: record.id,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            region: record.region,
            weather_location_id: record.weather_location_id
          )
        end

        def user_farm_snapshot(record)
          Domain::CultivationPlan::Dtos::PlanSaveUserFarmSnapshot.new(
            id: record.id,
            name: record.name,
            region: record.region
          )
        end
      end
    end
  end
end
