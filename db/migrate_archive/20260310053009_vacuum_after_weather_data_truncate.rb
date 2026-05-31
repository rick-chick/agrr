# frozen_string_literal: true

class VacuumAfterWeatherDataTruncate < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # VACUUM はメンテナンス用 rake タスクで実行（起動時のロック競合を避ける）
    # rails db:vacuum で手動実行
  end

  def down
    # VACUUM は不可逆
  end
end
