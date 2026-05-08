# frozen_string_literal: true

module Domain
  module FileBlob
    module Interactors
      class FileBlobListInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call
          @output_port.on_list_success(rows: @gateway.list_rows_ordered_desc)
        end
      end
    end
  end
end
