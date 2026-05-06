# frozen_string_literal: true

module Domain
  module Shared
    module Exceptions
      # ActiveRecord::RecordInvalid の代わりに Gateway / Adapter で翻訳して投げる。
      # ドメイン側はこの例外を捕捉してエラー応答に変換する。
      # `errors` は表現非依存（`Domain::Shared::ValidationErrors` 推奨、またはメッセージの Array）。
      # ActiveRecord インスタンスを載せない（DTO への ActiveRecord 混入・domain 境界の禁止に沿う）。
      class RecordInvalid < StandardError
        attr_reader :errors

        def initialize(message = nil, errors: nil)
          super(message)
          @errors = errors
        end

        # Array 期待のユースケース（例: マスタ作成失敗 DTO）向け
        def flatten_error_messages
          case @errors
          when nil then []
          when Array then @errors.map(&:to_s)
          when Domain::Shared::ValidationErrors then @errors.full_messages
          when Hash then @errors.values.flatten.map(&:to_s)
          else []
          end
        end
      end
    end
  end
end
