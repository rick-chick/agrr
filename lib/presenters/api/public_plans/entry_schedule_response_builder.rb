# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      # エントリスケジュール API 用 JSON 断片を組み立てる（T-035）。
      class EntryScheduleResponseBuilder
        ES = Domain::CultivationPlan::Interactors::EntrySchedule

        def self.prediction_meta(farm:, payload_hash:)
          return {} unless payload_hash.is_a?(Hash)

          {
            generated_at: payload_hash["generated_at"] || payload_hash["predicted_at"],
            prediction_start_date: payload_hash["prediction_start_date"],
            prediction_end_date: payload_hash["prediction_end_date"] || payload_hash["target_end_date"],
            weather_location_id: farm.weather_location_id,
            chart_calendar_year: Time.zone.today.year
          }.compact
        end

        # @param result [ES::WindowService::Result]
        def self.crop_list_item(crop, result)
          timeline = ES::EntrySchedulePhaseTimeline
          cw = timeline.chart_windows(crop, result)
          sow_first = cw[:sowing_windows].first
          tr_first = cw[:transplant_windows].first

          {
            id: crop.id,
            name: crop.name,
            eligible: result.eligible,
            sowing_summary: sow_first ? { start_date: sow_first[:start_date].iso8601, end_date: sow_first[:end_date].iso8601 } : nil,
            transplant_summary: tr_first ? { start_date: tr_first[:start_date].iso8601, end_date: tr_first[:end_date].iso8601 } : nil,
            reason_summary: reason_summary_text(result),
            labels: {
              sowing: I18n.t("api.entry_schedule.label.sowing"),
              transplanting: I18n.t("api.entry_schedule.label.transplanting")
            },
            schedule_flow_summary: timeline.schedule_flow_summary(crop, result),
            schedule_flow_detail: timeline.schedule_flow_detail(crop, result),
            phase_segments: timeline.phase_segments(crop, result),
            rough_timeline: timeline.rough_timeline(crop, result),
            sort_meta: timeline.sort_meta(crop, result, cw: cw)
          }
        end

        def self.crop_detail(crop, result)
          timeline = ES::EntrySchedulePhaseTimeline
          cw = timeline.chart_windows(crop, result)
          crop_list_item(crop, result).merge(
            sowing_windows: serialize_windows(cw[:sowing_windows]),
            transplant_windows: serialize_windows(cw[:transplant_windows]),
            reason_parts: result.reason_parts,
            sowing_stage_id: result.sowing_stage_id,
            transplant_stage_id: result.transplant_stage_id,
            crop_stages: crop.crop_stages.order(:order).map do |s|
              { id: s.id, name: s.name, order: s.order }
            end,
            entry_disclaimer: I18n.t("api.entry_schedule.disclaimer.short"),
            next_task: {
              available: false,
              code: "catalog",
              summary: nil
            }
          )
        end

        def self.serialize_windows(windows)
          windows.map do |w|
            { start_date: w[:start_date].iso8601, end_date: w[:end_date].iso8601 }
          end
        end

        def self.default_reason_summary(result)
          parts = result.reason_parts || {}
          return parts[:error].to_s if parts[:error]

          src = parts[:source] || parts["source"]
          if src.to_s == "agrr_optimize_period"
            return "agrr_optimize_period days=#{parts[:days_evaluated]}"
          end
          if src.to_s == "agrr_failed"
            ek = parts[:error_key] || parts["error_key"] || "generic"
            return "agrr_failed:#{ek}"
          end

          "sowing=#{parts[:sowing_stage_name]} transplant=#{parts[:transplant_stage_name]} days=#{parts[:days_evaluated]}"
        end

        def self.reason_summary_text(result)
          parts = result.reason_parts || {}
          return parts[:error].to_s if parts[:error]

          src = parts[:source] || parts["source"]
          if src.to_s == "agrr_optimize_period"
            return I18n.t(
              "api.entry_schedule.reason.agrr",
              start: (parts[:optimal_start_date] || parts["optimal_start_date"]).to_s.slice(0, 10),
              completion: (parts[:completion_date] || parts["completion_date"]).to_s.slice(0, 10),
              days: (parts[:growth_days] || parts["growth_days"]).to_i,
              gdd: (parts[:gdd] || parts["gdd"]).to_s
            )
          end
          if src.to_s == "agrr_failed"
            ek = (parts[:error_key] || parts["error_key"] || "generic").to_s
            return I18n.t("api.entry_schedule.reason.agrr_failed.#{ek}", default: I18n.t("api.entry_schedule.reason.agrr_failed.generic"))
          end

          I18n.t(
            "api.entry_schedule.reason.list",
            sowing: parts[:sowing_stage_name] || "-",
            transplant: parts[:transplant_stage_name] || "-",
            days: parts[:days_evaluated].to_i,
            default: default_reason_summary(result)
          )
        end

        # 一覧用: eligible → まき近さ → 帯の狭さ（昇順キー）
        def self.sort_tuple_for_list_item(item)
          sm = item[:sort_meta] || item["sort_meta"] || {}
          eligible = sm[:eligible] != false && sm["eligible"] != false ? 0 : 1
          prox = (sm[:sowing_proximity_days] || sm["sowing_proximity_days"]).to_i
          width = (sm[:sowing_window_width_days] || sm["sowing_window_width_days"]).to_i
          [ eligible, prox, width, item[:id] || item["id"].to_i ]
        end
      end
    end
  end
end
