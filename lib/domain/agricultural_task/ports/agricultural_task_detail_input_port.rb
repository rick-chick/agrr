# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Ports
      class AgriculturalTaskDetailInputPort
        def call(task_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
