# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.string :session_id, null: false
      t.text :data
      t.references :user, null: false, foreign_key: true
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :sessions, :session_id, unique: true
    add_index :sessions, :expires_at
  end
end

