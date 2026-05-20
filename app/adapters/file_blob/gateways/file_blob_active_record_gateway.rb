# frozen_string_literal: true

module Adapters
  module FileBlob
    module Gateways
      class FileBlobActiveRecordGateway < Domain::FileBlob::Gateways::FileBlobGateway
        def initialize(rails_blob_url_generator:)
          @rails_blob_url_generator = rails_blob_url_generator
        end

        def list_rows_ordered_desc
          ::ActiveStorage::Blob.order(created_at: :desc).map { |blob| build_row_dto(blob) }
        end

        def find_row_by_id(blob_id)
          blob = ::ActiveStorage::Blob.find_by(id: blob_id)
          return nil unless blob

          build_row_dto(blob)
        end

        def create_from_upload!(input:)
          blob = ::ActiveStorage::Blob.create_and_upload!(
            io: input.upload,
            filename: input.filename,
            content_type: input.content_type
          )
          build_row_dto(blob)
        end

        def purge(blob_id:)
          blob = ::ActiveStorage::Blob.find_by(id: blob_id)
          unless blob
            return Domain::FileBlob::Dtos::FileBlobPurgeOutput.new(purged: false)
          end

          blob.purge
          Domain::FileBlob::Dtos::FileBlobPurgeOutput.new(purged: true)
        end

        private

        def build_row_dto(blob)
          Domain::FileBlob::Dtos::FileBlobRow.new(
            id: blob.id,
            filename: blob.filename.to_s,
            content_type: blob.content_type,
            byte_size: blob.byte_size,
            created_at: blob.created_at.iso8601(3),
            url: @rails_blob_url_generator.call(blob)
          )
        end
      end
    end
  end
end
