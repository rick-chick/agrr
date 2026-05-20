# frozen_string_literal: true

module Domain
  module FileBlob
    module Dtos
      # ActiveStorage 由来のメタと URL を、ユースケース境界で受け渡す行スナップショット。
      # `created_at` はアダプターが ISO8601 文字列として詰める（Rails 型をドメイン契約に載せない）。
      class FileBlobRow
        attr_reader :id, :filename, :content_type, :byte_size, :created_at, :url

        def initialize(id:, filename:, content_type:, byte_size:, created_at:, url:)
          @id = id
          @filename = filename
          @content_type = content_type
          @byte_size = byte_size
          @created_at = created_at
          @url = url
        end
      end
    end
  end
end
