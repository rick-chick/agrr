# frozen_string_literal: true

class DropAgriculturalTaskCrops < ActiveRecord::Migration[8.0]
  def up
    # 外部キー制約を削除
    remove_foreign_key :agricultural_task_crops, :agricultural_tasks if foreign_key_exists?(:agricultural_task_crops, :agricultural_tasks)
    remove_foreign_key :agricultural_task_crops, :crops if foreign_key_exists?(:agricultural_task_crops, :crops)
    
    # テーブルを削除
    drop_table :agricultural_task_crops if table_exists?(:agricultural_task_crops)
  end

  def down
    # テーブルを再作成
    create_table :agricultural_task_crops do |t|
      t.references :agricultural_task, null: false, foreign_key: true
      t.references :crop, null: false, foreign_key: true

      t.timestamps
    end

    add_index :agricultural_task_crops, [:agricultural_task_id, :crop_id], unique: true, name: 'index_agricultural_task_crops_on_task_and_crop'
  end
end

