# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      # User モデル lookup。`Adapters::User` という名前空間は `::User` と衝突するため使わない。
      class UserActiveRecordGateway
        include Domain::Shared::Gateways::UserLookupGateway

        def find(user_id)
          record = ::User.find(user_id)
          Adapters::Shared::Mappers::UserMapper.user_dto_from_record(record)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
