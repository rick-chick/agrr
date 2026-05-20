# frozen_string_literal: true

module Domain
  module Field
    module Policies
      # 圃場のアクセス。旧 FieldPolicy と同一ルール。
      class FieldAccess
        def self.scope_for_farm(user, farm)
          raise Domain::Shared::Policies::PolicyPermissionDenied unless farm.user_id == user.id || user.admin?

          farm.fields
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
