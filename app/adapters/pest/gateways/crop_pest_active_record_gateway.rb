# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      class CropPestActiveRecordGateway < Domain::Pest::Gateways::CropPestGateway
        def find_by_crop_id_and_pest_id(crop_id:, pest_id:)
          record = ::CropPest.find_by(crop_id: crop_id, pest_id: pest_id)
          return nil unless record

          link_entity_from_record(record)
        end

        def list_by_pest_id(pest_id:)
          ::CropPest.where(pest_id: pest_id).pluck(:crop_id)
        end

        def create(crop_id:, pest_id:)
          record = ::CropPest.create!(crop_id: crop_id, pest_id: pest_id)
          link_entity_from_record(record)
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.record.errors.full_messages.join(", ")
        end

        def delete(crop_id:, pest_id:)
          record = ::CropPest.find_by(crop_id: crop_id, pest_id: pest_id)
          return false unless record

          record.destroy!
          true
        end

        private

        def link_entity_from_record(record)
          Domain::Pest::Entities::CropPestLinkEntity.new(
            id: record.id,
            crop_id: record.crop_id,
            pest_id: record.pest_id
          )
        end
      end
    end
  end
end
