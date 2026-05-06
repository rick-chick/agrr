# frozen_string_literal: true

module Domain
  module FileBlob
    module Interactors
      class ApiV1FilesShowInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(blob_id:)
          row = @gateway.find_row_by_id(blob_id)
          unless row
            @output_port.on_not_found
            return
          end
          @output_port.on_show_success(row: row)
        end
      end
    end
  end
end
