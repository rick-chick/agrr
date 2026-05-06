# frozen_string_literal: true

module Adapters
  module StoredBlobs
    module Gateways
      class ApiFileBlobActiveRecordGateway < Domain::FileBlob::Gateways::ApiFileBlobGateway
        def initialize(rails_blob_url_generator:)
          @rails_blob_url_generator = rails_blob_url_generator
        end

        def list_rows_ordered_desc
          ::ActiveStorage::Blob.order(created_at: :desc).map { |blob| row_hash(blob) }
        end

        def find_row_by_id(blob_id)
          blob = ::ActiveStorage::Blob.find_by(id: blob_id)
          return nil unless blob

          row_hash(blob)
        end

        def create_from_upload!(io:, filename:, content_type:)
          blob = ::ActiveStorage::Blob.create_and_upload!(
            io: io,
            filename: filename,
            content_type: content_type
          )
          row_hash(blob)
        end

        def purge!(blob_id)
          blob = ::ActiveStorage::Blob.find_by(id: blob_id)
          return false unless blob

          blob.purge
          true
        end

        private

        def row_hash(blob)
          {
            id: blob.id,
            filename: blob.filename.to_s,
            content_type: blob.content_type,
            byte_size: blob.byte_size,
            created_at: blob.created_at,
            url: @rails_blob_url_generator.call(blob)
          }
        end
      end
    end
  end
end
