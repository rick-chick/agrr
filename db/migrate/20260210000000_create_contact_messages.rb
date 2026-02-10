class CreateContactMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :contact_messages do |t|
      t.string :name
      t.string :email, null: false
      t.string :subject
      t.string :source
      t.text :message, null: false
      t.string :status, null: false, default: "queued"
      t.datetime :sent_at

      t.timestamps
    end
    add_index :contact_messages, :status
    add_index :contact_messages, :email
  end
end

