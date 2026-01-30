# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskDetailOutputDto
        attr_reader :task

        def initialize(task:)
          @task = task
        end
      end
    end
  end
end
