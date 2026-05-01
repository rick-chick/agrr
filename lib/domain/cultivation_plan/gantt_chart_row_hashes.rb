# frozen_string_literal: true

module Domain
  module CultivationPlan
    # ガント JS が data-cultivations / data-fields として読む Hash 形（キーは既存 partial と同一）。
    # ERB（AR）と Gateway 読み取り DTO の両方から共通変換する。
    module GanttChartRowHashes
      module_function

      def profit_from_optimization_result(opt)
        return nil unless opt.is_a?(Hash)

        opt["profit"] || opt[:profit]
      end

      def cultivation_row_from_ar(fc)
        # 日付は従来 partial（cultivation_plan:）どおり nil なら to_s で空文字（JSON の null にしない）
        {
          id: fc.id,
          field_id: fc.cultivation_plan_field_id,
          field_name: fc.field_display_name,
          crop_id: fc.cultivation_plan_crop_id,
          crop_name: fc.crop_display_name,
          start_date: fc.start_date.to_s,
          completion_date: fc.completion_date.to_s,
          cultivation_days: fc.cultivation_days,
          area: fc.area,
          estimated_cost: fc.estimated_cost,
          profit: fc.optimization_result&.dig("profit")
        }
      end

      def cultivation_row_from_read(read)
        {
          id: read.id,
          field_id: read.cultivation_plan_field_id,
          field_name: read.field_display_name,
          crop_id: read.cultivation_plan_crop_id,
          crop_name: read.crop_display_name,
          start_date: read.start_date&.to_s,
          completion_date: read.completion_date&.to_s,
          cultivation_days: read.cultivation_days,
          area: read.area,
          estimated_cost: read.estimated_cost,
          profit: read.optimization_profit
        }
      end

      def field_row_from_ar(field)
        {
          id: field.id,
          field_id: field.id,
          name: field.name,
          area: field.area
        }
      end

      def field_row_from_read(read)
        {
          id: read.id,
          field_id: read.id,
          name: read.name,
          area: read.area
        }
      end
    end
  end
end
