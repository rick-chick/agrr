# frozen_string_literal: true

module Agrr
  class ScheduleGateway < BaseGatewayV2
    def generate(crop_name:, variety:, stage_requirements:, agricultural_tasks:)
      stage_file = write_temp_file(stage_requirements, prefix: 'stage_requirements')
      tasks_file = write_temp_file(agricultural_tasks, prefix: 'agricultural_tasks')

      command_args = [
        'dummy_path',
        'schedule',
        '--crop-name', crop_name,
        '--variety', variety,
        '--stage-requirements', stage_file.path,
        '--agricultural-tasks', tasks_file.path,
        '--json'
      ]

      execute_command(*command_args)
    ensure
      stage_file&.close
      stage_file&.unlink
      tasks_file&.close
      tasks_file&.unlink
    end
  end
end

