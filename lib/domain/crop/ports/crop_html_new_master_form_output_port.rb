# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropHtmlNewMasterFormOutputPort
        # @param master_form_snapshot [Domain::Crop::Dtos::CropMasterFormSnapshot]
        def on_success(master_form_snapshot)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
