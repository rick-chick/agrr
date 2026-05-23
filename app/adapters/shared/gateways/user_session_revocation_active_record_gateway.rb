# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      class UserSessionRevocationActiveRecordGateway
        include Domain::Auth::Gateways::UserSessionRevocationGateway

        def delete_all_sessions_for_user!(user_id:)
          ::Session.where(user_id: user_id).delete_all
        end
      end
    end
  end
end
