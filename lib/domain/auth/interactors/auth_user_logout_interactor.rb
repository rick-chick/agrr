# frozen_string_literal: true

module Domain
  module Auth
    module Interactors
      # ログアウト: 認証済みなら永続セッションを削除し、ポートへ成功を通知する。
      class AuthUserLogoutInteractor
        def initialize(output_port:, session_revocation_gateway:)
          @output_port = output_port
          @session_revocation_gateway = session_revocation_gateway
        end

        # @param authenticated [Boolean] 実ユーザーでログイン済み（匿名でない）
        # @param user_id [Integer] current_user.id（認証済み時）
        def call(authenticated:, user_id:)
          unless authenticated
            @output_port.on_not_logged_in
            return
          end

          @session_revocation_gateway.delete_all_sessions_for_user!(user_id: user_id)
          @output_port.on_success
        end
      end
    end
  end
end
