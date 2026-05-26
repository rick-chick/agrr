# frozen_string_literal: true

require "ostruct"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserCropActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanSaveUserCropGateway
        def find_by_user_id_and_source_crop_id(user_id:, source_crop_id:)
          record = ::Crop.find_by(user_id: user_id, source_crop_id: source_crop_id)
          return nil unless record

          crop_duck(record)
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

          crop_duck(crop)
        end

        def list_by_ids(ids:)
          return [] if ids.empty?

          records = ::Crop.where(id: ids).to_a
          by_id = records.index_by(&:id)
          ids.filter_map { |id| by_id[id] }
        end

        private

        def crop_duck(record)
          ::OpenStruct.new(id: record.id)
        end
      end
    end
  end
end
