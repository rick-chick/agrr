# frozen_string_literal: true

# Seed data has been migrated to database migrations for better version control
# and integration with schema management.
#
# See:
# - db/migrate/20251018075019_seed_japan_reference_data.rb
# - db/migrate/20251018075149_seed_united_states_reference_data.rb
#
# To populate the database, run:
#   rails db:migrate
#
# This approach follows Rails 8 best practices for data migrations,
# using temporary models within migrations to avoid coupling to application code.

puts "✅ Seed data is managed through migrations. Run 'rails db:migrate' to populate data."

