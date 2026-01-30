namespace :i18n do
  desc "Synchronize Rails locales to Angular JSON files"
  task sync: :environment do
    script_path = Rails.root.join('scripts/sync_i18n.rb')
    system("ruby #{script_path}")
  end
end
