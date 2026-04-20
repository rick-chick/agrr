# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :session_id, :current_user

    def connect
      # セッションIDで識別（必須：public計画の認証に使用）
      # request.session may be nil in some environments; guard and ensure string
      self.session_id = request.session&.id.to_s

      # ログインユーザーを取得（optional：private計画の認証に使用）
      self.current_user = find_verified_user

      if current_user
        Rails.logger.info "🔌 [ActionCable::Connection] Connected: user_id=#{current_user.id}, session_id=#{session_id}"
        logger.add_tags "ActionCable", "User:#{current_user.id}", "Session:#{session_id}"
      else
        Rails.logger.info "🔌 [ActionCable::Connection] Connected: anonymous, session_id=#{session_id}"
        logger.add_tags "ActionCable", "Anonymous", "Session:#{session_id}"
      end
    end

    private

    def find_verified_user
      # このプロジェクトでは独自のSession管理を使用
      # cookies[:session_id]からセッションを取得
      session_id = cookies[:session_id]
      return nil unless session_id

      # セッションIDの形式を検証
      return nil unless Session.valid_session_id?(session_id)

      # アクティブなセッションを検索
      session = Session.active.find_by(session_id: session_id)
      return nil unless session

      # セッションからユーザーを取得
      session.user
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end
end
