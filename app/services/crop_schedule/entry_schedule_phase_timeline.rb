# frozen_string_literal: true

module CropSchedule
  # エントリ API 用: 4 フェーズ（播種/育苗/定植/収穫）と月次ざっくり時系列、一覧用短文
  class EntrySchedulePhaseTimeline
    class << self
      # @param crop [Crop]
      # @param result [CropSchedule::WindowService::Result]
      def phase_segments(crop, result)
        rp = result.reason_parts || {}
        src = rp[:source] || rp['source']
        return agrr_ratio_phase_segments(result) if src.to_s == 'agrr_optimize_period'

        weather_end = result.weather_end_date
        sow_first = result.sowing_windows.first
        tr_first = result.transplant_windows.first

        [
          segment_sowing(sow_first, weather_end, result.eligible),
          segment_nursery(sow_first, tr_first, weather_end, result.eligible),
          segment_transplant(tr_first, weather_end, result.eligible),
          segment_harvest(tr_first, weather_end, crop, result.eligible)
        ]
      end

      def rough_timeline(crop, result)
        segs = phase_segments(crop, result)
        ranges = []
        segs.each do |seg|
          next if seg[:start_date].blank? || seg[:end_date].blank?

          ranges << { start_date: Date.parse(seg[:start_date]), end_date: Date.parse(seg[:end_date]), label: seg[:label] }
        end
        return [] if ranges.empty?

        by_month = {}
        ranges.each do |r|
          walk_months(r[:start_date], r[:end_date]) do |month_start|
            key = month_start.strftime('%Y-%m')
            by_month[key] ||= []
            by_month[key] << r[:label]
          end
        end

        by_month.keys.sort.map do |ym|
          labels = by_month[ym].uniq
          {
            month: ym,
            summary: I18n.t('api.entry_schedule.timeline.month_summary', labels: labels.join('・'))
          }
        end
      end

      def schedule_flow_summary(crop, result)
        segs = phase_segments(crop, result)
        parts = segs.filter_map { |s| s[:label] if s[:empty_reason].blank? && s[:start_date].present? }
        if parts.empty?
          return I18n.t('api.entry_schedule.flow.summary_fallback')
        end

        I18n.t('api.entry_schedule.flow.summary', phases: parts.join('→'))
      end

      def schedule_flow_detail(crop, result)
        segs = phase_segments(crop, result)
        chunks = segs.filter_map do |s|
          next if s[:start_date].blank?

          I18n.t(
            'api.entry_schedule.flow.detail_chunk',
            label: s[:label],
            range: format_month_range(s[:start_date], s[:end_date])
          )
        end
        return nil if chunks.empty?

        chunks.join(' ')
      end

      # optimize period は「栽培開始〜完了」の1区間のみ返すが、API はまき／植えの2帯を出すため
      # 同一日付を二重に載せない。4 等分フェーズの播種・定植に相当する区間をチャート用に使う。
      # @return [Hash] { sowing_windows: Array<{start_date:, end_date: Date}>, transplant_windows: ... }
      def chart_windows(crop, result)
        rp = result.reason_parts || {}
        if rp[:source].to_s == 'agrr_optimize_period' && result.eligible
          segs = phase_segments(crop, result)
          sow_seg = segs.find { |s| s[:phase_key].to_s == 'sowing' && s[:empty_reason].blank? && s[:start_date].present? }
          tr_seg = segs.find { |s| s[:phase_key].to_s == 'transplant' && s[:empty_reason].blank? && s[:start_date].present? }
          out_sow = []
          out_tr = []
          if sow_seg
            out_sow << { start_date: Date.parse(sow_seg[:start_date]), end_date: Date.parse(sow_seg[:end_date]) }
          end
          if tr_seg
            out_tr << { start_date: Date.parse(tr_seg[:start_date]), end_date: Date.parse(tr_seg[:end_date]) }
          end
          return { sowing_windows: out_sow, transplant_windows: out_tr }
        end

        { sowing_windows: result.sowing_windows, transplant_windows: result.transplant_windows }
      end

      def sort_meta(crop, result, cw: nil)
        cw ||= chart_windows(crop, result)
        sow_first = cw[:sowing_windows].first
        {
          eligible: result.eligible,
          sowing_proximity_days: sowing_proximity_days(sow_first, result.eligible),
          sowing_window_width_days: window_width_days(sow_first)
        }
      end

      # AGRR optimize period は「栽培開始〜完了」の1区間。4フェーズは日数を4等分した概算表示。
      def agrr_ratio_phase_segments(result)
        w = result.sowing_windows.first
        weather_end = result.weather_end_date
        unless result.eligible && w
          return [
            phase_base(:sowing).merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.ineligible')),
            phase_base(:nursery).merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.ineligible')),
            phase_base(:transplant).merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.ineligible')),
            phase_base(:harvest).merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.ineligible'))
          ]
        end

        s0 = w[:start_date]
        e0 = w[:end_date]
        [
          segment_from_quarter(:sowing, s0, e0, 0),
          segment_from_quarter(:nursery, s0, e0, 1),
          segment_from_quarter(:transplant, s0, e0, 2),
          segment_harvest_from_quarter(s0, e0, weather_end, 3)
        ]
      end

      private

      def segment_from_quarter(phase_key, range_start, range_end, quarter_index)
        h = phase_base(phase_key)
        a, b = quarter_date_range(range_start, range_end, quarter_index)
        h.merge(start_date: a.iso8601, end_date: b.iso8601, empty_reason: nil)
      end

      def segment_harvest_from_quarter(s0, e0, weather_end, quarter_index)
        h = phase_base(:harvest)
        if weather_end.blank?
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.no_weather_end'))
        end

        a, b = quarter_date_range(s0, e0, quarter_index)
        end_d = [b, weather_end].min
        end_d = a if end_d < a
        h.merge(start_date: a.iso8601, end_date: end_d.iso8601, empty_reason: nil)
      end

      # quarter_index 0..3 で [range_start, range_end] の日数を4等分
      def quarter_date_range(range_start, range_end, quarter_index)
        total_days = (range_end - range_start).to_i + 1
        f0 = quarter_index / 4.0
        f1 = (quarter_index + 1) / 4.0
        start_off = (total_days * f0).floor
        end_off = (total_days * f1).ceil - 1
        a = range_start + start_off
        b = range_start + end_off
        b = range_end if b > range_end
        b = a if b < a
        [a, b]
      end

      def segment_sowing(sow_first, _weather_end, eligible)
        h = phase_base(:sowing)
        unless eligible
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.ineligible'))
        end
        if sow_first.blank?
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.no_sowing_window'))
        end

        h.merge(
          start_date: sow_first[:start_date].iso8601,
          end_date: sow_first[:end_date].iso8601,
          empty_reason: nil
        )
      end

      def segment_nursery(sow_first, tr_first, _weather_end, eligible)
        h = phase_base(:nursery)
        unless eligible
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.ineligible'))
        end
        if sow_first.blank? || tr_first.blank?
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.nursery_gap'))
        end

        start_d = sow_first[:end_date] + 1.day
        end_d = tr_first[:start_date] - 1.day
        if end_d < start_d
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.nursery_gap'))
        end

        h.merge(
          start_date: start_d.iso8601,
          end_date: end_d.iso8601,
          empty_reason: nil
        )
      end

      def segment_transplant(tr_first, _weather_end, eligible)
        h = phase_base(:transplant)
        unless eligible
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.ineligible'))
        end
        if tr_first.blank?
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.no_transplant_window'))
        end

        h.merge(
          start_date: tr_first[:start_date].iso8601,
          end_date: tr_first[:end_date].iso8601,
          empty_reason: nil
        )
      end

      def segment_harvest(tr_first, weather_end, _crop, eligible)
        h = phase_base(:harvest)
        unless eligible
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.ineligible'))
        end
        if tr_first.blank?
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.no_transplant_window'))
        end
        if weather_end.blank?
          return h.merge(empty_reason: I18n.t('api.entry_schedule.phase.empty.no_weather_end'))
        end

        start_d = tr_first[:end_date] + 1.day
        end_d = [weather_end, tr_first[:end_date] + 120.days].min
        end_d = start_d if end_d < start_d

        h.merge(
          start_date: start_d.iso8601,
          end_date: end_d.iso8601,
          empty_reason: nil
        )
      end

      def phase_base(key)
        {
          phase_key: key.to_s,
          label: I18n.t("api.entry_schedule.phase.label.#{key}"),
          start_date: nil,
          end_date: nil,
          empty_reason: nil
        }
      end

      def walk_months(start_date, end_date)
        d = start_date.beginning_of_month
        while d <= end_date
          yield d
          d = d.next_month
        end
      end

      def format_month_range(start_iso, end_iso)
        return '' if start_iso.blank?

        s = Date.parse(start_iso)
        e = end_iso.present? ? Date.parse(end_iso) : s
        I18n.t('api.entry_schedule.flow.month_range', start: s.strftime('%Y-%m'), end: e.strftime('%Y-%m'))
      end

      def sowing_proximity_days(sow_first, eligible)
        return 999_999 unless eligible
        return 999_999 if sow_first.blank?

        today = Date.current
        s = sow_first[:start_date]
        e = sow_first[:end_date]
        return 0 if (s..e).cover?(today)
        return (s - today).to_i if today < s

        (today - e).to_i + 1000
      end

      def window_width_days(sow_first)
        return 999_999 if sow_first.blank?

        (sow_first[:end_date] - sow_first[:start_date]).to_i + 1
      end
    end
  end
end
