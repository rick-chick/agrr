# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :session_id
    
    def connect
      # セッションIDで識別（認証不要の公開機能のため）
      self.session_id = request.session.id.to_s
      Rails.logger.info "🔌 [ActionCable::Connection] Connected with session_id: #{session_id}"
      logger.add_tags "ActionCable", "Session:#{session_id}"
    end
  end
end


