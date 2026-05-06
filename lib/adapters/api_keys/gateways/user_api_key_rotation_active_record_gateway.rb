# frozen_string_literal: true

module Adapters
  module ApiKeys
    module Gateways
      class UserApiKeyRotationActiveRecordGateway < Domain::ApiKeys::Gateways::UserApiKeyRotationGateway
        def rotate(user_id:, regenerate:)
          user = ::User.find(user_id)
          ok = regenerate ? user.regenerate_api_key! : user.generate_api_key!
          { ok: ok, api_key: user.api_key, error: nil }
        rescue ActiveRecord::RecordNotFound
          { ok: false, api_key: nil, error: :not_found }
        end
      end
    end
  end
end
