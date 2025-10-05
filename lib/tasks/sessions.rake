# frozen_string_literal: true

namespace :sessions do
  desc "Clean up expired sessions"
  task cleanup: :environment do
    expired_count = Session.cleanup_expired
    puts "Cleaned up #{expired_count} expired sessions"
  end

  desc "Show session statistics"
  task stats: :environment do
    total_sessions = Session.count
    active_sessions = Session.active.count
    expired_sessions = Session.expired.count
    
    puts "Session Statistics:"
    puts "  Total sessions: #{total_sessions}"
    puts "  Active sessions: #{active_sessions}"
    puts "  Expired sessions: #{expired_sessions}"
    
    if total_sessions > 0
      puts "  Average sessions per user: #{(total_sessions.to_f / User.count).round(2)}"
    end
  end
end

