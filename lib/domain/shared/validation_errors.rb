# frozen_string_literal: true

module Domain
  module Shared
    # 属性別メッセージ配列を保持する最小 errors API（domain 層のバリデーション用）
    class ValidationErrors
      def initialize
        @messages_by_attribute = {}
      end

      def add(attribute, message)
        key = attribute.to_sym
        (@messages_by_attribute[key] ||= []) << message.to_s
      end

      def [](attribute)
        key = attribute.to_sym
        Array(@messages_by_attribute[key]).dup
      end

      def empty?
        @messages_by_attribute.values.all?(&:empty?)
      end

      # ActiveModel::Errors に近い使い方: 引数なしはエラー有無、ブロック付きは full_messages を走査
      def any?(&block)
        return !empty? unless block

        full_messages.any?(&block)
      end

      # ActiveModel::Errors との互換性（ビューで `errors.count` が呼ばれる）
      def count
        full_messages.size
      end

      def messages
        @messages_by_attribute.each_with_object({}) do |(key, msgs), acc|
          acc[key] = msgs.dup unless msgs.empty?
        end
      end

      # Presenter / JSON で使うフラット列（順序は安定しない）
      def full_messages
        messages.flat_map { |_attr, msgs| msgs }
      end

      # アダプタ境界: ActiveModel::Errors や Hash / 文字列配列をドメイン側の表現に落とす（Rails 定数は参照しない）。
      def self.from_errors_like(obj)
        ve = new
        return ve if obj.nil?
        return obj if obj.is_a?(ValidationErrors)

        if obj.is_a?(Array)
          obj.each { |m| ve.add(:base, m.to_s) }
          return ve
        end

        if obj.is_a?(Hash)
          obj.each do |attr, msgs|
            Array(msgs).compact.each { |m| ve.add(attr, m.to_s) }
          end
          return ve
        end

        if obj.respond_to?(:to_hash)
          obj.to_hash(true).each do |attr, msgs|
            Array(msgs).compact.each { |m| ve.add(attr, m.to_s) }
          end
        end

        ve
      end
    end
  end
end
