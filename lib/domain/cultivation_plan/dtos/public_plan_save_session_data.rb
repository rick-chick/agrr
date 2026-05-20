# frozen_string_literal: true

require "time"

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存フローのセッション／ゲートウェイ境界用ペイロード（無型 Hash を渡さない）。
      # 属性は整数・配列・圃場行 DTO・created_at（UTC Time またはセッション用 ISO8601 文字列）に限定する。
      # Params の変換は Adapter（PlanSaveSessionDataCoercion）で Hash に潰してから渡す。
      class PublicPlanSaveSessionData
        attr_reader :plan_id, :farm_id, :crop_ids, :field_data, :created_at

        # @param crop_ids [Array<Integer>]
        # @param field_data [Array<PublicPlanSaveFieldDatum>]
        # @param created_at [Time, String, nil] Time は UTC に正規化して保持。String は from_session_hash / initialize 時にパース。
        def initialize(plan_id:, farm_id:, crop_ids: [], field_data: [], created_at: nil)
          @plan_id = plan_id.to_i
          @farm_id = farm_id&.to_i
          @crop_ids = crop_ids.freeze
          @field_data = field_data.freeze
          @created_at = coerce_created_at_attr(created_at)
          freeze
        end

        # @param h [Hash, nil] キーはシンボルまたは文字列。値はプリミティブ／配列／圃場行の Hash のみ想定。
        # @return [PublicPlanSaveSessionData, nil] plan_id が取れないときは nil
        def self.from_session_hash(h)
          return nil if h.nil?
          return nil unless h.is_a?(Hash)

          plan_id = fetch_key(h, :plan_id)
          return nil if missing_plan_id?(plan_id)

          farm_id = fetch_key(h, :farm_id)
          crop_ids = Array(fetch_key(h, :crop_ids)).map(&:to_i)

          raw_fields = fetch_key(h, :field_data)
          field_data = Array(raw_fields).filter_map do |row|
            dto = PublicPlanSaveFieldDatum.from_row(row)
            dto if dto
          end

          created_at = fetch_key(h, :created_at)

          new(
            plan_id: plan_id.to_i,
            farm_id: farm_id&.to_i,
            crop_ids: crop_ids,
            field_data: field_data,
            created_at: created_at
          )
        end

        # Rails session / JSON 互換（キーはシンボル、created_at は ISO8601 文字列）
        # @return [Hash]
        def to_session_hash
          {
            plan_id: plan_id,
            farm_id: farm_id,
            crop_ids: crop_ids,
            field_data: field_data.map(&:to_session_row),
            created_at: created_at_iso8601_string
          }.compact
        end

        def self.fetch_key(h, key)
          sym = key.to_sym
          str = key.to_s
          h[sym] || h[str]
        end
        private_class_method :fetch_key

        def self.missing_plan_id?(plan_id)
          plan_id.nil? || plan_id.to_s.strip.empty?
        end
        private_class_method :missing_plan_id?

        # @param value [String, Time, nil]
        # @return [Time, nil] UTC
        def self.parse_created_at(value)
          return nil if value.nil?
          return nil if value.is_a?(String) && value.strip.empty?

          case value
          when Time
            value.utc
          when String
            parse_created_at_string(value)
          else
            nil
          end
        end
        private_class_method :parse_created_at

        def self.parse_created_at_string(s)
          Time.iso8601(s)
        rescue ArgumentError
          Time.parse(s)
        rescue ArgumentError, TypeError
          nil
        end
        private_class_method :parse_created_at_string

        def coerce_created_at_attr(value)
          self.class.send(:parse_created_at, value)
        end
        private :coerce_created_at_attr

        def created_at_iso8601_string
          return nil if created_at.nil?

          created_at.utc.iso8601(3)
        end
        private :created_at_iso8601_string
      end
    end
  end
end
