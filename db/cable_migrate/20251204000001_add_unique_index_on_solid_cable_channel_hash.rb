# frozen_string_literal: true

class AddUniqueIndexOnSolidCableChannelHash < ActiveRecord::Migration[8.0]
  def change
    # solid_cable_messagesテーブルのchannel_hashにユニークインデックスを追加
    # insert_allのunique_byオプションが正しく動作するために必要
    remove_index :solid_cable_messages, :channel_hash, if_exists: true
    add_index :solid_cable_messages, :channel_hash, unique: true
  end
end

