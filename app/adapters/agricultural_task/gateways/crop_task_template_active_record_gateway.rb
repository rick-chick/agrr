# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Gateways
      class CropTaskTemplateActiveRecordGateway < Domain::AgriculturalTask::Gateways::CropTaskTemplateGateway
        def list_by_agricultural_task_id(agricultural_task_id:)
          ::CropTaskTemplate.where(agricultural_task_id: agricultural_task_id).map do |record|
            Adapters::AgriculturalTask::Mappers::CropTaskTemplateLinkMapper.link_entity_from_record(record)
          end
        end

        def find_by_agricultural_task_id_and_crop_id(agricultural_task_id:, crop_id:)
          record = ::CropTaskTemplate.find_by(agricultural_task_id: agricultural_task_id, crop_id: crop_id)
          return nil unless record

          Adapters::AgriculturalTask::Mappers::CropTaskTemplateLinkMapper.link_entity_from_record(record)
        end

        def create(agricultural_task_id:, crop_id:, attrs:)
          record = ::CropTaskTemplate.create!(
            attrs.to_h.symbolize_keys.merge(agricultural_task_id: agricultural_task_id, crop_id: crop_id)
          )
          Adapters::AgriculturalTask::Mappers::CropTaskTemplateLinkMapper.link_entity_from_record(record)
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved,
               ActiveRecord::StatementInvalid => e
          raise map_active_record_failure(e)
        end

        def delete(agricultural_task_id:, crop_id:)
          template = ::CropTaskTemplate.find_by(agricultural_task_id: agricultural_task_id, crop_id: crop_id)
          template&.destroy
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved,
               ActiveRecord::StatementInvalid => e
          raise map_active_record_failure(e)
        end

        private

        def map_active_record_failure(error)
          case error
          when ActiveRecord::RecordInvalid
            Domain::Shared::Exceptions::RecordInvalid.new(error.record.errors.full_messages.join(", "))
          else
            Domain::Shared::Exceptions::RecordInvalid.new(error.message)
          end
        end
      end
    end
  end
end
