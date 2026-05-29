# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskShowDetailReadActiveRecordGateway <
          Domain::AgriculturalTask::Gateways::AgriculturalTaskShowDetailReadGateway
        def find_show_detail_snapshot(task_id:)
          task = ::AgriculturalTask.includes(:crops).find(task_id)
          Mappers::AgriculturalTaskShowDetailSnapshotMapper.from_model(task)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
