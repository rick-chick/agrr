# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Ports
      class AgriculturalTaskHtmlNewMasterFormOutputPort
        def on_success(task_for_form)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
