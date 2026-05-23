# frozen_string_literal: true

module Domain
  module Farm
    module Ports
      class FarmHtmlNewMasterFormOutputPort
        # @param master_form_snapshot [Domain::Farm::Dtos::FarmMasterFormSnapshot]
        def on_success(master_form_snapshot)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
