# frozen_string_literal: true

module Domain
  module Shared
    module Exceptions
      # ActiveRecord::RecordInvalid の代わりに Gateway / Adapter で翻訳して投げる。
      # ドメイン側はこの例外を捕捉してエラー応答に変換する。
      # Adapter 側は ActiveRecord::RecordInvalid 由来の `record.errors` を `errors` として保持して再 raise する。
      class RecordInvalid < StandardError
        attr_reader :errors, :record

        def initialize(message = nil, errors: nil, record: nil)
          super(message)
          @errors = errors
          @record = record
        end
      end
    end
  end
end
