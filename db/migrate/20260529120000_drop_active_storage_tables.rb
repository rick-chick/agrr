# frozen_string_literal: true

class DropActiveStorageTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :active_storage_variant_records, if_exists: true
    drop_table :active_storage_attachments, if_exists: true
    drop_table :active_storage_blobs, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
