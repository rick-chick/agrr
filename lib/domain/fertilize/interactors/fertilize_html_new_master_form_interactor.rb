# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeHtmlNewMasterFormInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call
          snapshot = @gateway.blank_fertilize_master_form_snapshot_for_html
          @output_port.on_success(snapshot)
        end
      end
    end
  end
end
