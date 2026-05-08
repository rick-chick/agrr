# frozen_string_literal: true

module Domain
  module FileBlob
    module Interactors
      class FileBlobDestroyInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(blob_id:)
          ok = @gateway.purge!(blob_id)
          unless ok
            @output_port.on_not_found
            return
          end
          @output_port.on_deleted
        end
      end
    end
  end
end
