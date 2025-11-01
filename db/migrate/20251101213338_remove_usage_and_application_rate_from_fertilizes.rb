class RemoveUsageAndApplicationRateFromFertilizes < ActiveRecord::Migration[8.0]
  def change
    remove_column :fertilizes, :usage, :text
    remove_column :fertilizes, :application_rate, :string
  end
end
