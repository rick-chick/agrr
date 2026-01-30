# frozen_string_literal: true

class AddUniqueIndexesOnSolidQueueIds < ActiveRecord::Migration[8.0]
  def change
    # SolidQueueのすべてのテーブルにidカラムの一意インデックスを追加
    # upsert_allが正しく動作するために必要
    %i[
      solid_queue_jobs
      solid_queue_blocked_executions
      solid_queue_claimed_executions
      solid_queue_failed_executions
      solid_queue_pauses
      solid_queue_processes
      solid_queue_ready_executions
      solid_queue_recurring_executions
      solid_queue_recurring_tasks
      solid_queue_scheduled_executions
      solid_queue_semaphores
    ].each do |table|
      # 既にインデックスが存在する場合はスキップ
      unless index_exists?(table, :id)
        add_index table, :id, unique: true
      end
    end
  end
end





