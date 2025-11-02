class RemoveSourcesAndNotesFromCropFertilizeProfiles < ActiveRecord::Migration[8.0]
  def change
    remove_column :crop_fertilize_profiles, :sources, :text
    remove_column :crop_fertilize_profiles, :notes, :text
  end
end
