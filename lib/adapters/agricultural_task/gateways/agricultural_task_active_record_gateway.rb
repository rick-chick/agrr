# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskActiveRecordGateway < Domain::AgriculturalTask::Gateways::AgriculturalTaskGateway
        def list
          ::AgriculturalTask.all.map { |record| Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.from_model(record) }
        end

        def find_by_id(task_id)
          task = ::AgriculturalTask.find(task_id)
          Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.from_model(task)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'AgriculturalTask not found'
        end

        def create(create_input_dto)
          task = ::AgriculturalTask.new(
            name: create_input_dto.name,
            description: create_input_dto.description,
            time_per_sqm: create_input_dto.time_per_sqm,
            weather_dependency: create_input_dto.weather_dependency,
            required_tools: create_input_dto.required_tools,
            skill_level: create_input_dto.skill_level,
            region: create_input_dto.region,
            task_type: create_input_dto.task_type
          )
          raise StandardError, task.errors.full_messages.join(', ') unless task.save

          Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.from_model(task)
        end

        def update(task_id, update_input_dto)
          task = ::AgriculturalTask.find(task_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:time_per_sqm] = update_input_dto.time_per_sqm if !update_input_dto.time_per_sqm.nil?
          attrs[:weather_dependency] = update_input_dto.weather_dependency if !update_input_dto.weather_dependency.nil?
          attrs[:required_tools] = update_input_dto.required_tools if !update_input_dto.required_tools.nil?
          attrs[:skill_level] = update_input_dto.skill_level if !update_input_dto.skill_level.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          attrs[:task_type] = update_input_dto.task_type if !update_input_dto.task_type.nil?

          task.update(attrs)
          raise StandardError, task.errors.full_messages.join(', ') if task.errors.any?

          Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.from_model(task.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'AgriculturalTask not found'
        end

        def destroy(task_id)
          task = ::AgriculturalTask.find(task_id)
          DeletionUndo::Manager.schedule(
            record: task,
            actor: User.find(task.user_id),
            toast_message: I18n.t('agricultural_tasks.undo.toast', name: task.name)
          )
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'AgriculturalTask not found'
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, I18n.t('agricultural_tasks.flash.cannot_delete_in_use')
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
        end
      end
    end
  end
end
