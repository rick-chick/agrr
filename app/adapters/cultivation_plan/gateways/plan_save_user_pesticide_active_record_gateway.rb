# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserPesticideActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanSaveUserPesticideGateway
        def find_by_user_id_and_source_pesticide_id(user_id:, source_pesticide_id:)
          record = ::Pesticide.find_by(user_id: user_id, source_pesticide_id: source_pesticide_id)
          return nil unless record

          pesticide_snapshot(record)
        end

        def create(
          user_id:,
          attributes:,
          usage_constraint_attributes: nil,
          application_detail_attributes: nil
        )
          user = ::User.find_by(id: user_id)
          unless user
            raise Domain::Shared::Exceptions::RecordNotFound, "User not found: #{user_id}"
          end

          record = nil
          ::Pesticide.transaction do
            pesticide = user.pesticides.build(attributes)
            unless pesticide.save
              raise Domain::Shared::Exceptions::RecordInvalid, pesticide.errors.full_messages.join(", ")
            end

            if usage_constraint_attributes
              pesticide.create_pesticide_usage_constraint!(usage_constraint_attributes)
            end

            if application_detail_attributes
              pesticide.create_pesticide_application_detail!(application_detail_attributes)
            end

            record = pesticide
          end

          pesticide_snapshot(record)
        end

        private

        def pesticide_snapshot(record)
          Domain::CultivationPlan::Dtos::PlanSaveUserPesticideSnapshot.new(
            id: record.id,
            name: record.name
          )
        end
      end
    end
  end
end
