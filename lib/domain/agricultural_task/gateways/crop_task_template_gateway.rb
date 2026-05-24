# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Gateways
      class CropTaskTemplateGateway
        # @return [Array<Domain::AgriculturalTask::Entities::CropTaskTemplateLinkEntity>]
        def list_by_agricultural_task_id(agricultural_task_id:)
          raise NotImplementedError, "Subclasses must implement list_by_agricultural_task_id"
        end

        # @return [Domain::AgriculturalTask::Entities::CropTaskTemplateLinkEntity, nil]
        def find_by_agricultural_task_id_and_crop_id(agricultural_task_id:, crop_id:)
          raise NotImplementedError, "Subclasses must implement find_by_agricultural_task_id_and_crop_id"
        end

        def create(agricultural_task_id:, crop_id:, attrs:)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def delete(agricultural_task_id:, crop_id:)
          raise NotImplementedError, "Subclasses must implement delete"
        end
      end
    end
  end
end
