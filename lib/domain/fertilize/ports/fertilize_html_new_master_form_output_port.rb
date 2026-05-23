# frozen_string_literal: true

module Domain
  module Fertilize
    module Ports
      class FertilizeHtmlNewMasterFormOutputPort
        # @param master_form_snapshot [Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot]
        def on_success(master_form_snapshot)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
