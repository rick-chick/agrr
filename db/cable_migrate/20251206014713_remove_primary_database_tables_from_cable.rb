# frozen_string_literal: true

class RemovePrimaryDatabaseTablesFromCable < ActiveRecord::Migration[8.0]
  # cableデータベースからプライマリDBのテーブルを削除するマイグレーション
  # 本番環境で実行する場合、データベースのバックアップを取ってから実行すること
  
  def up
    # solid_cable_messages以外のすべてのテーブルを削除
    # ただし、システムテーブル（schema_migrations, ar_internal_metadata）と
    # solid_cache_entries（誤って混入している場合）は除外
    
    tables_to_remove = connection.tables.reject do |table|
      table == 'solid_cable_messages' ||
      table == 'schema_migrations' ||
      table == 'ar_internal_metadata' ||
      table.start_with?('sqlite_')
    end
    
    tables_to_remove.each do |table|
      if table_exists?(table)
        say "Removing table: #{table}"
        drop_table table, force: :cascade
      end
    end
  end
  
  def down
    # ロールバックは不可能（削除されたテーブルを復元できない）
    raise ActiveRecord::IrreversibleMigration,
      "Cannot reverse this migration: tables were permanently removed"
  end
end
