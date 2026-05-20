# frozen_string_literal: true

module Domain
  module Shared
    # Rails の String#demodulize / underscore（ActiveSupport Inflector）に依存しない dom セグメント。
    # UpperCamelCase のクラス名・モジュール付き文字列を snake_case にする（ASCII 想定）。
    module ClassNameDomSegment
      module_function

      # @param class_name [#to_s] 例: "Domain::Foo::BarPest"
      # @return [String] 例: "bar_pest"
      def from_class_name(class_name)
        Domain::Shared::FormModelName.snake_case(class_name.to_s)
      end
    end
  end
end
