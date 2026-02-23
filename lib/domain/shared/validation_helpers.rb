# frozen_string_literal: true

module Domain
  module Shared
    module ValidationHelpers
      # ActiveSupportのblank?とpresent?のRails非依存代替実装
      # 既存のblank?/present?と同じ振る舞いを維持

      def self.present?(value)
        !blank?(value)
      end

      def self.blank?(value)
        case value
        when nil, false
          true
        when true
          false
        when String
          value.strip.empty?
        when Array, Hash
          value.empty?
        else
          false
        end
      end

      # Array() のRails非依存代替実装
      def self.to_array(value)
        case value
        when nil
          []
        when Array
          value
        else
          [value]
        end
      end
    end
  end
end