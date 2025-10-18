class AddNameToSolidQueueProcesses < ActiveRecord::Migration[8.0]
  def change
    add_column :solid_queue_processes, :name, :string
  end
end
