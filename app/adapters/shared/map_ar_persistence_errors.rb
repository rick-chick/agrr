# frozen_string_literal: true

module Adapters
  module Shared
    # ActiveRecord の永続化系例外をドメイン例外に寄せる（lib/domain から AR 定数を隠す）。
    module MapArPersistenceErrors
      module_function

      def with_mapped_ar_persistence_failure
        yield
      rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
        raise Domain::Shared::Exceptions::PersistenceFailed.new(e.message), cause: e
      end
    end
  end
end
