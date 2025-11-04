# frozen_string_literal: true

class RemoveConfidenceFromCropFertilizeProfiles < ActiveRecord::Migration[8.0]
  def change
    remove_column :crop_fertilize_profiles, :confidence, :float
  end
end




