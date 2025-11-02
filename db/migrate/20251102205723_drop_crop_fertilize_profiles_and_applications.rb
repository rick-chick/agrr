# frozen_string_literal: true

class DropCropFertilizeProfilesAndApplications < ActiveRecord::Migration[8.0]
  def change
    # Foreign key constraints を削除
    remove_foreign_key :crop_fertilize_applications, :crop_fertilize_profiles if foreign_key_exists?(:crop_fertilize_applications, :crop_fertilize_profiles)
    remove_foreign_key :crop_fertilize_profiles, :crops if foreign_key_exists?(:crop_fertilize_profiles, :crops)
    
    # テーブルを削除
    drop_table :crop_fertilize_applications, if_exists: true do |t|
      t.references :crop_fertilize_profile, null: false, foreign_key: true
      t.string :application_type, null: false
      t.integer :count, default: 1, null: false
      t.string :schedule_hint
      t.float :per_application_n
      t.float :per_application_p
      t.float :per_application_k
      t.timestamps
    end

    drop_table :crop_fertilize_profiles, if_exists: true do |t|
      t.references :crop, null: false, foreign_key: true
      t.timestamps
    end
  end
end

