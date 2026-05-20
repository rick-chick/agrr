# frozen_string_literal: true

module Domain
  module Shared
    # ActiveSupport の Kernel#deep_dup / ActiveSupport::DeepDupable に依存しない深複製。
    # Hash / Array とプリミティブ（および dup 可能な軽量オブジェクト）のみを想定する。
    module DeepDup
      module_function

      def deep_dup(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), h|
            h[deep_dup(k)] = deep_dup(v)
          end
        when Array
          obj.map { |e| deep_dup(e) }
        else
          duplicate_leaf(obj)
        end
      end

      def duplicate_leaf(obj)
        case obj
        when NilClass, TrueClass, FalseClass, Integer, Float, Symbol
          obj
        when String
          obj.dup
        else
          obj.respond_to?(:dup) ? obj.dup : obj
        end
      end
    end
  end
end
