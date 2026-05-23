# frozen_string_literal: true

module Domain
  module Auth
    module Gateways
      # ユーザーに紐づく永続セッション行の削除（表現・HTTP 非依存）
      module UserSessionRevocationGateway
        # @param user_id [Integer]
        def delete_all_sessions_for_user!(user_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
