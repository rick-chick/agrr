class AddLastBroadcastAtToFarms < ActiveRecord::Migration[8.0]
  def change
    add_column :farms, :last_broadcast_at, :datetime
  end
end
