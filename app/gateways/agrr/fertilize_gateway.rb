# frozen_string_literal: true

module Agrr
  class FertilizeGateway < BaseGatewayV2
    def plan(crop:, use_harvest_start: true)
      crop_requirement = crop.to_agrr_requirement
      crop_file = write_temp_file(crop_requirement, prefix: 'fertilize_crop')

      command_args = [
        'dummy_path',
        'fertilize',
        'plan',
        '--crop-file', crop_file.path
      ]
      command_args << '--use-harvest-start' if use_harvest_start
      command_args << '--json'

      execute_command(*command_args)
    ensure
      crop_file&.close
      crop_file&.unlink
    end
  end
end

