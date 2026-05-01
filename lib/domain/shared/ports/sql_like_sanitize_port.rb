# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # SQL LIKE 用エスケープ（実装は Adapter。生成は CompositionRoot のみ）
      module SqlLikeSanitizePort
        def sanitize_like(term)
          raise NotImplementedError, "#{self.class}#sanitize_like"
        end
      end
    end
  end
end
