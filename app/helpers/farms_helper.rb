# frozen_string_literal: true

module FarmsHelper
  # FarmListRow 用。キーは app/models/farm.rb#weather_data_status_text と揃える。
  def farm_list_row_weather_status_text(row)
    case row.weather_data_status
    when "pending"
      t("models.farm.weather_status.pending")
    when "fetching"
      t("models.farm.weather_status.fetching", progress: row.weather_data_progress)
    when "completed"
      t("models.farm.weather_status.completed")
    when "failed"
      t("models.farm.weather_status.failed")
    else
      t("models.farm.weather_status.unknown")
    end
  end
end
