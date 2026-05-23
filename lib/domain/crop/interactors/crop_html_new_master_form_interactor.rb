# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropHtmlNewMasterFormInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call
          snapshot = @gateway.blank_crop_master_form_snapshot_for_html
          @output_port.on_success(snapshot)
        end
      end
    end
  end
end
