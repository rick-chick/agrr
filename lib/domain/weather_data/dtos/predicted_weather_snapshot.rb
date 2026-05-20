# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # `predicted_weather_data` JSON カラム相当のドキュメント（agrr / 予測パイプライン由来の Hash）。
      # ゲートウェイ境界では生 Hash を渡さず、この DTO で受ける（中身は段階的に子型へ分解可能）。
      class PredictedWeatherSnapshot
        # @return [Hash, nil]
        attr_reader :document

        # @param document [Hash, nil] 文字列キーを想定。nil は永続化側でカラムクリア。
        def initialize(document:)
          @document = self.class.__send__(:deep_freeze_document, document)
          freeze
        end

        # @param doc [Hash, nil]
        # @return [PredictedWeatherSnapshot]
        def self.from_document(doc)
          case doc
          when nil then new(document: nil)
          when Hash then new(document: doc)
          else
            raise ArgumentError, "PredictedWeatherSnapshot.from_document expects Hash or nil, got #{doc.class}"
          end
        end

        # @param payload [PredictedWeatherSnapshot, Hash, nil]
        # @return [Hash, nil]
        def self.storage_column_value(payload)
          case payload
          when nil then nil
          when PredictedWeatherSnapshot then payload.to_storage_hash
          when Hash then from_document(payload).to_storage_hash
          else
            raise ArgumentError, "expected PredictedWeatherSnapshot, Hash, or nil, got #{payload.class}"
          end
        end

        # ActiveRecord JSON カラムへ渡すミュータブル複製（nil はクリア）。
        # @return [Hash, nil]
        def to_storage_hash
          return nil if document.nil?

          Marshal.load(Marshal.dump(document))
        end

        def self.deep_freeze_document(doc)
          case doc
          when nil then nil
          when Hash then doc.transform_values { |v| deep_freeze_document(v) }.freeze
          when Array then doc.map { |v| deep_freeze_document(v) }.freeze
          else
            doc
          end
        end
        private_class_method :deep_freeze_document
      end
    end
  end
end
