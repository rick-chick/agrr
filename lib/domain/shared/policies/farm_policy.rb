# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class FarmPolicy
        def self.view_allowed?(user, is_reference:, user_id:)
          user.admin? || is_reference || user_id == user.id
        end

        # 所有農場（非参照かつ自分のもの）または管理者
        def self.owned_visible?(user, is_reference:, user_id:)
          user.admin? || (!is_reference && user_id == user.id)
        end

        def self.edit_allowed?(user, is_reference:, user_id:)
          user.admin? || (!is_reference && user_id == user.id)
        end

        def self.record_access_filter(user)
          Domain::Shared::ReferenceRecordAccessFilter.new(user: user, policy_module: self)
        end

        def self.normalize_attrs_for_create(user, attrs)
          h = attrs.to_h.symbolize_keys
          h[:user_id] = user.id
          h[:is_reference] = false
          h
        end

        def self.normalize_attrs_for_update(_user, _current_attrs, requested_attrs)
          requested_attrs.to_h.symbolize_keys
        end
      end
    end
  end
end
