# frozen_string_literal: true

module Domain
  module FileBlob
    module Interactors
      class FileBlobCreateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(io:, filename:, content_type:)
          unless io.present?
            @output_port.on_missing_file
            return
          end

          row = @gateway.create_from_upload!(io: io, filename: filename, content_type: content_type)
          @output_port.on_created(row: row)
        end
      end
    end
  end
end
