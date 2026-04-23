# frozen_string_literal: true

module Domain
  module Shared
    # LIKE 検索用エスケープを Framework の 1 箇所に閉じる（Interactor は参照しない）。
    module SqlLike
      module_function

      def sanitize(term)
        Domain::Shared::Ports::SqlLikeSanitizePort.default.sanitize_like(term)
      end
    end
  end
end
