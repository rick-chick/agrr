# frozen_string_literal: true

class FixAvatarUrlsInUsers < ActiveRecord::Migration[8.0]
  def up
    # Fix avatar_url for users that have full /assets/ paths
    # Convert '/assets/farm-avatar.svg' to 'farm-avatar.svg'
    User.find_each do |user|
      next if user.avatar_url.blank?
      next unless user.avatar_url.start_with?('/assets/')
      
      new_avatar_url = user.avatar_url.sub(%r{\A/assets/}, '')
      user.update_column(:avatar_url, new_avatar_url)
    end
  end

  def down
    # Revert is not necessary as the old format was incorrect
    # and caused 404 errors with Propshaft
  end
end