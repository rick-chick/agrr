module FieldCultivationClimate
  module MockProgressRecords
    def generate_mock_progress_records(start_date, end_date)
      records = []
      current_date = start_date
      cumulative_gdd = 0.0
      stage_names = I18n.t('controllers.field_cultivations.mock_progress.stage_names')
      stage_thresholds = [75.0, 375.0, 875.0]

      while current_date <= end_date
        daily_gdd = rand(12.0..18.0).round(2)
        cumulative_gdd += daily_gdd

        stage_name = if cumulative_gdd <= stage_thresholds[0]
          stage_names[0]
        elsif cumulative_gdd <= stage_thresholds[1]
          stage_names[1]
        else
          stage_names[2]
        end

        records << {
          'date' => current_date.to_s,
          'cumulative_gdd' => cumulative_gdd.round(2),
          'stage_name' => stage_name
        }

        current_date += 1.day
      end

      Rails.logger.info "🧪 [FieldCultivationClimate::MockProgressRecords] Generated #{records.length} records, GDD range: 0-#{records.last['cumulative_gdd']}"
      Rails.logger.info "🧪 [FieldCultivationClimate::MockProgressRecords] Stage distribution: #{records.group_by { |r| r['stage_name'] }.transform_values(&:count)}"

      records
    end
  end
end
