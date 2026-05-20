# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      # Google OAuth コールバックでのユーザー作成・セッション作成（AR / DB 例外は本アダプタに閉じる）
      class AuthOmniauthSessionActiveRecordGateway
        CallbackResult = Struct.new(:status, :user, :session, :omniauth_error_class, keyword_init: true)

        # @return [CallbackResult]
        def process_google_callback(auth_hash, logger: Rails.logger)
          return CallbackResult.new(status: :no_auth_hash) if auth_hash.nil?

          user = ::User.from_omniauth(auth_hash)
          unless user.persisted?
            return CallbackResult.new(status: :user_not_persisted)
          end

          user_session = ::Session.create_for_user(user)
          CallbackResult.new(status: :success, user: user, session: user_session)
        rescue ActiveRecord::RecordInvalid => e
          logger.error "OAuth callback error: #{e.message}"
          CallbackResult.new(status: :record_invalid)
        rescue OmniAuth::Error => e
          logger.error "OAuth callback OmniAuth error: #{e.class} #{e.message}"
          CallbackResult.new(status: :omniauth_error, omniauth_error_class: e.class.name)
        rescue ActiveRecord::ConnectionNotEstablished,
               ActiveRecord::StatementInvalid,
               ActiveRecord::RecordNotUnique,
               Net::OpenTimeout,
               Net::ReadTimeout,
               Net::WriteTimeout,
               SocketError,
               Errno::ECONNRESET,
               Errno::ETIMEDOUT,
               Errno::ECONNREFUSED,
               OpenSSL::SSL::SSLError,
               EOFError,
               IOError => e
          logger.error "OAuth callback infrastructure error: #{e.class} #{e.message}"
          CallbackResult.new(status: :infrastructure_error)
        end
      end
    end
  end
end
