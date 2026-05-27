# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveFieldActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanSaveFieldGateway
        def list_by_farm_id(farm_id:, user_id:)
          ::Field
            .where(farm_id: farm_id, user_id: user_id)
            .order(:id)
            .map { |record| field_entity_from_record(record) }
        end

        def create(farm_id:, user_id:, attributes:)
          farm = ::Farm.find_by(id: farm_id)
          unless farm
            raise Domain::Shared::Exceptions::RecordNotFound,
                  I18n.t("services.plan_save_service.errors.farm_not_found", farm_id: farm_id)
          end

          user = ::User.find_by(id: user_id)
          unless user
            raise Domain::Shared::Exceptions::RecordNotFound, "User not found: #{user_id}"
          end

          field = farm.fields.build(
            user: user,
            name: attributes[:name],
            area: attributes[:area],
            description: attributes[:description]
          )

          unless field.save
            raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ")
          end

          field_entity_from_record(field)
        end

        private

        def field_entity_from_record(record)
          Domain::Field::Entities::FieldEntity.new(
            id: record.id,
            farm_id: record.farm_id,
            user_id: record.user_id,
            name: record.name,
            description: record.description,
            created_at: record.created_at,
            updated_at: record.updated_at,
            area: record.area,
            daily_fixed_cost: record.daily_fixed_cost,
            region: record.region
          )
        end
      end
    end
  end
end
