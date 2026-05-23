# frozen_string_literal: true

module Domain
  module Field
    module Policies
      # 圃場のアクセス。旧 FieldPolicy と同一ルール。
      class FieldAccess
        def self.assert_farm_fields_list_allowed!(user, farm_entity)
          allowed = user.admin? || farm_entity.user_id == user.id
          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed
        end

        def self.assert_field_edit_on_farm_allowed!(user, farm_entity)
          access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, farm_entity)
        end

        def self.find_owned!(user, id)
          field = ::Field.find(id)

          allowed =
            if user.admin?
              true
            else
              field.farm.user_id == user.id
            end

          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          field
        end

        def self.build_for_create(user, farm, attrs)
          attributes = Domain::Shared.symbolize_keys(attrs.to_h)

          attributes[:user_id] ||= user.id
          attributes[:farm_id] = farm.id

          ::Field.new(attributes)
        end
      end
    end
  end
end
