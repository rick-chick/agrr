# frozen_string_literal: true

namespace :db do
  desc "VACUUM primary database (run during low-traffic maintenance)"
  task vacuum: :environment do
    ActiveRecord::Base.connection.execute("VACUUM")
  end
end
