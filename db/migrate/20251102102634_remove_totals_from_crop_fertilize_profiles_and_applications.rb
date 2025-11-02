# frozen_string_literal: true

class RemoveTotalsFromCropFertilizeProfilesAndApplications < ActiveRecord::Migration[8.0]
  def change
    # CropFertilizeProfileからtotalsカラムを削除
    remove_column :crop_fertilize_profiles, :total_n, :float
    remove_column :crop_fertilize_profiles, :total_p, :float
    remove_column :crop_fertilize_profiles, :total_k, :float
    
    # CropFertilizeApplicationからtotalsカラムを削除
    remove_column :crop_fertilize_applications, :total_n, :float
    remove_column :crop_fertilize_applications, :total_p, :float
    remove_column :crop_fertilize_applications, :total_k, :float
  end
end
