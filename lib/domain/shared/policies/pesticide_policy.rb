# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class PesticidePolicy
        def self.view_allowed?(user, is_reference:, user_id:)
          ReferencableResourcePolicy.visible_for_user?(user, is_reference: is_reference, user_id: user_id)
        end

        def self.edit_allowed?(user, is_reference:, user_id:)
          view_allowed?(user, is_reference: is_reference, user_id: user_id)
        end

        # @return [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def self.index_list_filter(user)
          mode = user.admin? ? :reference_or_owned : :owned_non_reference
          Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: mode, user_id: user.id)
        end

        # 作物マスタ配下の農薬一覧: 作物へのアクセスは別 Interactor で検証済み。参照 + 自所有を表示。
        def self.masters_crop_pesticides_index_filter(user)
          Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: :reference_or_owned, user_id: user.id)
        end

        def self.record_access_filter(user)
          Domain::Shared::ReferenceRecordAccessFilter.new(user: user, policy_module: self)
        end

        # 参照可能マスタ共通の正規化（region/is_reference/user_id）は
        # ReferencableResourcePolicy へ委譲する。
        def self.normalize_attrs_for_create(user, attrs)
          Domain::Shared::Policies::ReferencableResourcePolicy
            .normalize_referencable_attrs_for_create(user, attrs)
        end

        def self.normalize_attrs_for_update(user, current_attrs, requested_attrs)
          Domain::Shared::Policies::ReferencableResourcePolicy
            .normalize_referencable_attrs_for_update(user, current_attrs, requested_attrs)
        end
      end
    end
  end
end
