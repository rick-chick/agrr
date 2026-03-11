# frozen_string_literal: true

class TruncateWeatherDataForGcsMigration < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM weather_data"
  end

  def down
    # Irreversible: data was migrated to GCS
  end
end
