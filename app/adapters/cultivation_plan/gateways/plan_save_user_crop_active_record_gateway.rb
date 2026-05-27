# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserCropActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanSaveUserCropGateway
        def find_by_user_id_and_source_crop_id(user_id:, source_crop_id:)
          record = ::Crop.find_by(user_id: user_id, source_crop_id: source_crop_id)
          return nil unless record

          crop_snapshot(record)
        end

        def create(user_id:, attributes:)
          user = ::User.find_by(id: user_id)
          unless user
            raise Domain::Shared::Exceptions::RecordNotFound, "User not found: #{user_id}"
          end

          crop = user.crops.build(attributes)
          unless crop.save
            raise Domain::Shared::Exceptions::RecordInvalid, crop.errors.full_messages.join(", ")
          end

          crop_snapshot(crop)
        end

        private

        def crop_snapshot(record)
          Domain::CultivationPlan::Dtos::PlanSaveUserCropSnapshot.new(id: record.id)
        end
      end
    end
  end
end
