# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserPestActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanSaveUserPestGateway
        def find_by_user_id_and_source_pest_id(user_id:, source_pest_id:)
          record = ::Pest.find_by(user_id: user_id, source_pest_id: source_pest_id)
          return nil unless record

          pest_snapshot(record)
        end

        def create(user_id:, attributes:)
          user = ::User.find_by(id: user_id)
          unless user
            raise Domain::Shared::Exceptions::RecordNotFound, "User not found: #{user_id}"
          end

          pest = user.pests.build(attributes)
          unless pest.save
            raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ")
          end

          pest_snapshot(pest)
        end

        def create_temperature_profile(pest_id:, attributes:)
          pest = ::Pest.find(pest_id)
          pest.create_pest_temperature_profile!(attributes)
        end

        def create_thermal_requirement(pest_id:, attributes:)
          pest = ::Pest.find(pest_id)
          pest.create_pest_thermal_requirement!(attributes)
        end

        def create_control_method(pest_id:, attributes:)
          pest = ::Pest.find(pest_id)
          pest.pest_control_methods.create!(attributes)
        end

        def link_crop_pest(crop_id:, pest_id:)
          pest = ::Pest.find(pest_id)
          ::CropPest.find_or_create_by!(crop_id: crop_id, pest: pest)
        end

        private

        def pest_snapshot(record)
          Domain::CultivationPlan::Dtos::PlanSaveUserPestSnapshot.new(
            id: record.id,
            name: record.name
          )
        end
      end
    end
  end
end
