# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Mappers
      # +AgriculturalTask+ レコードから {Domain::AgriculturalTask::Dtos::AgriculturalTaskMasterFormSnapshot} を組み立てる。
      class AgriculturalTaskMasterFormSnapshotMapper
        class << self
          # @param task [::AgriculturalTask]
          # @param error_messages [Array<String>]
          # @return [Domain::AgriculturalTask::Dtos::AgriculturalTaskMasterFormSnapshot]
          def from_record(task, error_messages: [])
            Domain::AgriculturalTask::Dtos::AgriculturalTaskMasterFormSnapshot.new(
              id: task.id,
              user_id: task.user_id,
              name: task.name,
              description: task.description,
              time_per_sqm: task.time_per_sqm,
              weather_dependency: task.weather_dependency,
              required_tools: task.required_tools || [],
              skill_level: task.skill_level,
              region: task.region,
              task_type: task.task_type,
              is_reference: task.is_reference,
              new_record: task.new_record?,
              error_messages: Array(error_messages)
            )
          end
        end
      end
    end
  end
end
