# frozen_string_literal: true

module Domain
  module Shared
    # RecordInvalid の errors（Hash または #to_hash）を、Presenter 向けの String キー＋メッセージ配列に揃える。
    module ValidationErrorHash
      module_function

      def from(errors)
        return errors if errors.is_a?(Hash)
        return {} if errors.nil?

        if errors.is_a?(Domain::Shared::ValidationErrors)
          return errors.messages.transform_keys(&:to_s).transform_values { |msgs| Array(msgs).compact }
        end

        return {} unless errors.respond_to?(:to_hash)

        hash = errors.to_hash(true).transform_keys(&:to_s)
        hash.transform_values! { |messages| Array(messages).compact }
        hash
      end
    end
  end
end
