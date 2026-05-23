# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskMasterFormCreateFailure
        attr_reader :message, :task_for_form

        def initialize(message:, task_for_form:)
          @message = message
          @task_for_form = task_for_form
        end
      end
    end
  end
end
