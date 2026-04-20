# frozen_string_literal: true

module CropSchedule
  # 予測気象（日次）とステージ別温度要件から「まき」「植え」の適期帯（連続日）を算出する
  class WindowService
    Result = Struct.new(
      :eligible,
      :sowing_windows,
      :transplant_windows,
      :reason_parts,
      :sowing_stage_id,
      :transplant_stage_id,
      :weather_end_date,
      keyword_init: true
    )

    # @param crop [Crop]
    # @param weather_payload [Hash] Farm/CultivationPlan の predicted_weather_data 相当（'data' => 日次配列）
    # @return [Result]
    def self.call(crop:, weather_payload:)
      new(crop: crop, weather_payload: weather_payload).call
    end

    def initialize(crop:, weather_payload:)
      @crop = crop
      @weather_payload = weather_payload || {}
    end

    def call
      sow_st = StageRoleResolver.sowing_stage(@crop)
      tr_st = StageRoleResolver.transplant_stage(@crop)

      unless sow_st && tr_st && sow_st.temperature_requirement && tr_st.temperature_requirement
        return empty_result(reason: :missing_stages_or_temperature)
      end

      daily = extract_daily_series
      if daily.empty?
        return empty_result(reason: :no_weather_series)
      end

      sow_ok_dates = daily.filter_map { |row| row[:date] if day_viable?(row, sow_st.temperature_requirement) }
      tr_ok_dates = daily.filter_map { |row| row[:date] if day_viable?(row, tr_st.temperature_requirement) }

      weather_end = daily.map { |r| r[:date] }.max

      Result.new(
        eligible: true,
        sowing_windows: merge_consecutive_dates(sow_ok_dates),
        transplant_windows: merge_consecutive_dates(tr_ok_dates),
        reason_parts: {
          rule: "temperature_thresholds",
          sowing_stage_name: sow_st.name,
          transplant_stage_name: tr_st.name,
          days_evaluated: daily.size
        },
        sowing_stage_id: sow_st.id,
        transplant_stage_id: tr_st.id,
        weather_end_date: weather_end
      )
    end

    private

    def empty_result(reason:)
      Result.new(
        eligible: false,
        sowing_windows: [],
        transplant_windows: [],
        reason_parts: { error: reason.to_s },
        sowing_stage_id: nil,
        transplant_stage_id: nil,
        weather_end_date: nil
      )
    end

    # @return [Array<Hash{:date=>Date, :t_min=>Float, :t_max=>Float, :t_mean=>Float}>]
    def extract_daily_series
      data = @weather_payload["data"] || @weather_payload[:data]
      return [] unless data.is_a?(Array)

      rows = []
      data.each do |datum|
        next unless datum.is_a?(Hash)

        date = parse_day(datum)
        next unless date

        t_max = float_val(datum["temperature_2m_max"] || datum[:temperature_2m_max])
        t_min = float_val(datum["temperature_2m_min"] || datum[:temperature_2m_min])
        t_mean = float_val(datum["temperature_2m_mean"] || datum[:temperature_2m_mean])
        if t_mean.nil? && t_max && t_min
          t_mean = (t_max + t_min) / 2.0
        end
        next unless t_max && t_min && t_mean

        rows << { date: date, t_min: t_min, t_max: t_max, t_mean: t_mean }
      end
      rows.sort_by { |r| r[:date] }.uniq { |r| r[:date] }
    end

    def parse_day(datum)
      raw = datum["time"] || datum["date"] || datum[:time] || datum[:date]
      return nil if raw.blank?

      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def float_val(v)
      return nil if v.nil?

      Float(v)
    rescue ArgumentError, TypeError
      nil
    end

    # 1日がステージの温度要件を満たすか（MVP: 霜条件 + 適温レンジ）
    def day_viable?(row, temp_req)
      t_min = row[:t_min]
      t_mean = row[:t_mean]
      return false unless t_min && t_mean

      if temp_req.frost_threshold.present?
        return false if t_min < temp_req.frost_threshold.to_f
      end

      if temp_req.optimal_min.present? && temp_req.optimal_max.present?
        return t_mean >= temp_req.optimal_min.to_f && t_mean <= temp_req.optimal_max.to_f
      end

      if temp_req.optimal_min.present?
        return t_mean >= temp_req.optimal_min.to_f
      end

      if temp_req.base_temperature.present?
        return t_min >= temp_req.base_temperature.to_f
      end

      false
    end

    def merge_consecutive_dates(dates)
      return [] if dates.empty?

      sorted = dates.uniq.sort
      ranges = []
      range_start = sorted.first
      prev = sorted.first

      sorted[1..]&.each do |d|
        if d == prev + 1
          prev = d
        else
          ranges << { start_date: range_start, end_date: prev }
          range_start = d
          prev = d
        end
      end
      ranges << { start_date: range_start, end_date: prev }
      ranges
    end
  end
end
