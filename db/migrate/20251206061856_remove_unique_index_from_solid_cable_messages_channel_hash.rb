class RemoveUniqueIndexFromSolidCableMessagesChannelHash < ActiveRecord::Migration[8.0]
  def up
    # channel_hashのUNIQUE制約を削除
    # 同じチャンネルに複数のメッセージを送信できるようにする（根本解決）
    # 注意: channel_hashはチャンネル名のみから計算されるため、
    # 同じチャンネルに複数のメッセージを送信するとchannel_hashが重複する
    # これは正常な動作なので、UNIQUE制約を削除する
    if index_exists?(:solid_cable_messages, :channel_hash, unique: true)
      remove_index :solid_cable_messages, :channel_hash
      # 非UNIQUEインデックスとして再作成（パフォーマンスのため）
      add_index :solid_cable_messages, :channel_hash, unique: false
    end
  end

  def down
    # ロールバック時はUNIQUE制約を復元
    if index_exists?(:solid_cable_messages, :channel_hash)
      remove_index :solid_cable_messages, :channel_hash
      add_index :solid_cable_messages, :channel_hash, unique: true
    end
  end
end
