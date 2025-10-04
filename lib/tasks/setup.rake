# frozen_string_literal: true

namespace :setup do
  desc "Setup development environment"
  task dev: :environment do
    puts "Setting up development environment..."
    
    # Create storage directories
    FileUtils.mkdir_p(Rails.root.join("storage"))
    FileUtils.mkdir_p(Rails.root.join("tmp/storage"))
    
    puts "Storage directories created"
    
    # Create database if it doesn't exist
    begin
      ActiveRecord::Base.connection
      puts "Database connection successful"
    rescue ActiveRecord::NoDatabaseError
      puts "Creating database..."
      Rake::Task["db:create"].invoke
      Rake::Task["db:migrate"].invoke
    end
    
    puts "Development environment setup completed!"
  end
  
  desc "Setup production environment"
  task prod: :environment do
    puts "Setting up production environment..."
    
    # Precompile assets
    Rake::Task["assets:precompile"].invoke
    
    # Run migrations
    Rake::Task["db:migrate"].invoke
    
    puts "Production environment setup completed!"
  end
end
