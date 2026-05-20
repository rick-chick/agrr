# frozen_string_literal: true

module Domain
  module FileBlob
    module Dtos
      # 削除要求の結果（対象が存在しなかった場合は `purged` が false）。
      class FileBlobPurgeOutput
        attr_reader :purged

        def initialize(purged:)
          @purged = purged
        end

        def purged?
          purged
        end
      end
    end
  end
end
