# frozen_string_literal: true

module Domain
  module Shared
    # RecordInvalid の errors（Hash または #to_hash）を、Presenter 向けの String キー＋メッセージ配列に揃える。
    module ValidationErrorHash
      module_function

      def from(errors)
        return errors if errors.is_a?(Hash)
        return {} unless errors.respond_to?(:to_hash)

        hash = errors.to_hash(true).transform_keys(&:to_s)
        hash.transform_values! { |messages| Array(messages).compact }
        hash
      end
    end
  end
end
