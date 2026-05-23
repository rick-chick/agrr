# frozen_string_literal: true

module Domain
  module FileBlob
    module Gateways
      class FileBlobGateway
        def list_rows_ordered_desc
          raise NotImplementedError
        end

        def find_by_id(blob_id)
          raise NotImplementedError
        end

        def create_from_upload!(io:, filename:, content_type:)
          raise NotImplementedError
        end

        def purge!(blob_id)
          raise NotImplementedError
        end
      end
    end
  end
end
