# frozen_string_literal: true

class AddUniqueIndexOnSolidCableMessagesId < ActiveRecord::Migration[8.0]
  def change
    # solid_cable_messagesテーブルにidカラムの一意インデックスを追加
    # insert_allが正しく動作するために必要
    return unless table_exists?(:solid_cable_messages)
    
    unless index_exists?(:solid_cable_messages, :id)
      add_index :solid_cable_messages, :id, unique: true
    end
  end
end

