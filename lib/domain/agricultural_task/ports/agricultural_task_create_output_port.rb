# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Ports
      class AgriculturalTaskCreateOutputPort
        def on_success(task)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
