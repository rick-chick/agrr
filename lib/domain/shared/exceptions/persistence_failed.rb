# frozen_string_literal: true

module Domain
  module Shared
    module Exceptions
      # 永続化層（DB 接続・SQL 等）の失敗。アダプタが ActiveRecord 由来の例外から変換して投げる。
      # Interactor / エンティティは ActiveRecord::* を参照しない（ARCHITECTURE.md 禁止 2）。
      class PersistenceFailed < StandardError
      end
    end
  end
end
