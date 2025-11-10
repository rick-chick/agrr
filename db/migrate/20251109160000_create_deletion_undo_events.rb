class CreateDeletionUndoEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :deletion_undo_events, id: :string do |t|
      t.string :resource_type, null: false
      t.string :resource_id, null: false
      t.json :snapshot, null: false, default: {}
      t.json :metadata, null: false, default: {}
      t.references :deleted_by, null: true, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.string :state, null: false, default: 'scheduled'
      t.datetime :restored_at
      t.datetime :finalized_at

      t.timestamps
    end

    add_index :deletion_undo_events, [:resource_type, :resource_id], name: 'index_deletion_undo_events_on_resource', where: "state = 'scheduled'"
    add_index :deletion_undo_events, :expires_at
  end
end

