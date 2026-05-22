# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class AgriculturalTaskPolicy
        def self.view_allowed?(user, is_reference:, user_id:)
          user.admin? || is_reference || user_id == user.id
        end

        # マスター API: 作物に紐付ける農業タスクは参照タスクまたは自ユーザーのタスクのみ（管理者も他人所有タスクは不可）
        def self.masters_crop_task_template_associate_allowed?(user, is_reference:, user_id:)
          is_reference || user_id == user.id
        end

        def self.edit_allowed?(user, is_reference:, user_id:)
          user.admin? || (!is_reference && user_id == user.id)
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
