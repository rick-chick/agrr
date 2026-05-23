# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestHtmlNewMasterFormOutputPort
        # @param state [Domain::Pest::Dtos::PestHtmlNewFormState]
        def on_success(state)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
