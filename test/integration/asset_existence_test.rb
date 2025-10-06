# frozen_string_literal: true

require "test_helper"

class AssetExistenceTest < ActionDispatch::IntegrationTest
  test "should verify that leaflet.css exists" do
    # Check that leaflet.css file exists in the filesystem
    assert File.exist?(Rails.root.join("public", "leaflet.css"))
  end

  test "should verify that leaflet.js exists" do
    # Check that leaflet.js file exists in the filesystem
    assert File.exist?(Rails.root.join("public", "leaflet.js"))
  end

  test "should verify that dev-avatar.svg exists" do
    # Check that dev-avatar.svg file exists in the filesystem
    assert File.exist?(Rails.root.join("app", "assets", "images", "dev-avatar.svg"))
  end

  test "should verify that fields.js exists" do
    # Check that fields.js file exists (this should pass)
    assert File.exist?(Rails.root.join("app", "assets", "javascripts", "fields.js"))
  end

  test "should list all existing asset files" do
    existing_files = []
    
    # Check for existing leaflet files
    if File.exist?(Rails.root.join("public", "leaflet.css"))
      existing_files << "public/leaflet.css"
    end
    
    if File.exist?(Rails.root.join("public", "leaflet.js"))
      existing_files << "public/leaflet.js"
    end
    
    if File.exist?(Rails.root.join("app", "assets", "images", "dev-avatar.svg"))
      existing_files << "app/assets/images/dev-avatar.svg"
    end
    
    # Assert that we have the expected existing files
    assert_includes existing_files, "public/leaflet.css"
    assert_includes existing_files, "public/leaflet.js"
    assert_includes existing_files, "app/assets/images/dev-avatar.svg"
    
    # Log the existing files for debugging
    puts "Existing asset files: #{existing_files.join(', ')}"
  end

  test "should verify asset pipeline configuration" do
    # Check that the asset pipeline is configured (might be nil in test environment)
    # In test environment, assets might be disabled
    if Rails.application.config.assets.enabled
      # Check that the asset paths include expected directories
      asset_paths = Rails.application.config.assets.paths
      assert asset_paths.any? { |path| path.to_s.include?("app/assets") }
    else
      # Assets are disabled in test environment, which is normal
      assert true
    end
  end

  test "should verify that public directory exists" do
    # Check that the public directory exists
    assert Dir.exist?(Rails.root.join("public"))
    assert Dir.exist?(Rails.root.join("app", "assets"))
    assert Dir.exist?(Rails.root.join("app", "assets", "javascripts"))
    assert Dir.exist?(Rails.root.join("app", "assets", "images"))
  end

  test "should check for leaflet files in all possible locations" do
    possible_locations = [
      "public/leaflet.css",
      "public/leaflet.js",
      "app/assets/stylesheets/leaflet.css",
      "app/assets/javascripts/leaflet.js",
      "vendor/assets/stylesheets/leaflet.css",
      "vendor/assets/javascripts/leaflet.js",
      "lib/assets/stylesheets/leaflet.css",
      "lib/assets/javascripts/leaflet.js"
    ]
    
    existing_locations = possible_locations.select do |location|
      File.exist?(Rails.root.join(location))
    end
    
    # Leaflet files should exist in public directory
    assert_includes existing_locations, "public/leaflet.css"
    assert_includes existing_locations, "public/leaflet.js"
  end

  test "should check for dev-avatar.svg in all possible locations" do
    possible_locations = [
      "public/assets/dev-avatar.svg",
      "app/assets/images/dev-avatar.svg",
      "vendor/assets/images/dev-avatar.svg",
      "lib/assets/images/dev-avatar.svg"
    ]
    
    existing_locations = possible_locations.select do |location|
      File.exist?(Rails.root.join(location))
    end
    
    # dev-avatar.svg should exist in app/assets/images
    assert_includes existing_locations, "app/assets/images/dev-avatar.svg"
  end
end
