# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FileBlob
    module Interactors
      class FileBlobCreateInteractorTest < DomainLibTestCase
        setup do
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = FileBlobCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway
          )
        end

        test "on_missing_file when upload is blank" do
          input = Domain::FileBlob::Dtos::FileBlobCreateUploadInput.new(
            upload: nil,
            filename: "x.txt",
            content_type: "text/plain"
          )
          @mock_gateway.expects(:create_from_upload!).never
          @mock_output_port.expects(:on_missing_file)

          @interactor.call(input: input)
        end

        test "on_created with gateway row dto" do
          upload = stub(read: "data")
          row = Domain::FileBlob::Dtos::FileBlobRow.new(
            id: 1,
            filename: "f.bin",
            content_type: "application/octet-stream",
            byte_size: 4,
            created_at: "2026-05-10T12:00:00.000Z",
            url: "http://example/blob"
          )
          input = Domain::FileBlob::Dtos::FileBlobCreateUploadInput.new(
            upload: upload,
            filename: "f.bin",
            content_type: "application/octet-stream"
          )
          @mock_gateway.expects(:create_from_upload!).with(io: upload, filename: "f.bin", content_type: "application/octet-stream").returns(row)
          @mock_output_port.expects(:on_created).with(row: row)

          @interactor.call(input: input)
        end
      end

      class FileBlobDestroyInteractorTest < DomainLibTestCase
        setup do
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = FileBlobDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway
          )
        end

        test "on_not_found when purge did not delete" do
          @mock_gateway.expects(:purge!).with(99).returns(false)
          @mock_output_port.expects(:on_not_found)

          @interactor.call(blob_id: 99)
        end

        test "on_deleted when purged" do
          @mock_gateway.expects(:purge!).with(42).returns(true)
          @mock_output_port.expects(:on_deleted)

          @interactor.call(blob_id: 42)
        end
      end
    end
  end
end
