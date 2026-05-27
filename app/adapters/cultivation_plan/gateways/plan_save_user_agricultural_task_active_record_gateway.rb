# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserAgriculturalTaskActiveRecordGateway <
          Domain::CultivationPlan::Gateways::PlanSaveUserAgriculturalTaskGateway
        def find_by_user_id_and_source_agricultural_task_id(user_id:, source_agricultural_task_id:)
          record = ::AgriculturalTask.find_by(
            user_id: user_id,
            source_agricultural_task_id: source_agricultural_task_id
          )
          return nil unless record

          agricultural_task_snapshot(record)
        end

        def create(user_id:, attributes:)
          user = ::User.find_by(id: user_id)
          unless user
            raise Domain::Shared::Exceptions::RecordNotFound, "User not found: #{user_id}"
          end

          task = user.agricultural_tasks.build(attributes)
          unless task.save
            raise Domain::Shared::Exceptions::RecordInvalid, task.errors.full_messages.join(", ")
          end

          agricultural_task_snapshot(task)
        end

        def find_crop_task_template(crop_id:, agricultural_task_id:)
          record = ::CropTaskTemplate.find_by(
            crop_id: crop_id,
            agricultural_task_id: agricultural_task_id
          )
          return nil unless record

          Domain::CultivationPlan::Dtos::PlanSaveCropTaskTemplateLinkSnapshot.new(id: record.id)
        end

        def create_crop_task_template(crop_id:, agricultural_task_id:, attributes:)
          record = ::CropTaskTemplate.create!(
            attributes.to_h.symbolize_keys.merge(
              crop_id: crop_id,
              agricultural_task_id: agricultural_task_id
            )
          )

          Domain::CultivationPlan::Dtos::PlanSaveCropTaskTemplateLinkSnapshot.new(id: record.id)
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.record.errors.full_messages.join(", ")
        end

        private

        def agricultural_task_snapshot(record)
          Domain::CultivationPlan::Dtos::PlanSaveUserAgriculturalTaskSnapshot.new(
            id: record.id,
            name: record.name
          )
        end
      end
    end
  end
end
