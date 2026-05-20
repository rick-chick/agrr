# frozen_string_literal: true

module Domain
  module FileBlob
    module Dtos
      # アップロード 1 件分。`upload` は `#read` を実装すればよい（アダプターが ActiveStorage に渡す）。
      class FileBlobCreateUploadInput
        attr_reader :upload, :filename, :content_type

        def initialize(upload:, filename:, content_type:)
          @upload = upload
          @filename = filename
          @content_type = content_type
        end
      end
    end
  end
end
