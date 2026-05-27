# frozen_string_literal: true

module Domain
  module Field
    module Policies
      # 圃場のアクセス。旧 FieldPolicy と同一ルール（ORM 非依存）。
      module FieldAccess
        module_function

        def assert_farm_fields_list_allowed!(user, farm_entity)
          allowed = user.admin? || farm_entity.user_id == user.id
          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed
        end

        def assert_field_edit_on_farm_allowed!(user, farm_entity)
          access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, farm_entity)
        end

        # @param farm [Domain::Farm::Entities::FarmEntity]
        def assert_owned!(user, farm:)
          allowed = user.admin? || farm.user_id == user.id
          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed
        end
      end
    end
  end
end
