# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class PestPolicy
        # @return [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def self.index_list_filter(user)
          mode = user.admin? ? :reference_or_owned : :owned_non_reference
          Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: mode, user_id: user.id)
        end

        # マスタ作物への害虫紐付け候補（参照害虫 + 自分の害虫）。
        def self.selectable_list_filter(user)
          Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: :reference_or_owned, user_id: user.id)
        end

        # @param is_reference [Boolean]
        # @param user_id [Integer, nil]
        def self.selectable_for_user?(user, is_reference:, user_id:)
          is_reference == true || user_id.to_i == user.id.to_i
        end

        def self.record_access_filter(user)
          Domain::Shared::ReferenceRecordAccessFilter.new(user: user, policy_module: self)
        end

        def self.view_allowed?(user, is_reference:, user_id:)
          is_reference || user_id == user.id
        end

        def self.edit_allowed?(user, is_reference:, user_id:)
          if user.admin?
            is_reference || user_id == user.id
          else
            !is_reference && user_id == user.id
          end
        end

        # 参照可能マスタ共通の正規化（region/is_reference/user_id）は
        # ReferencableResourcePolicy へ委譲する。admin_forced はバルク取込用の特権経路。
        def self.normalize_attrs_for_create(user, attrs, admin_forced: false)
          Domain::Shared::Policies::ReferencableResourcePolicy
            .normalize_referencable_attrs_for_create(user, attrs, admin_forced: admin_forced)
        end

        def self.normalize_attrs_for_update(user, current_attrs, requested_attrs)
          pest = Domain::Shared.symbolize_keys(current_attrs.to_h)
          attributes = Domain::Shared.symbolize_keys(requested_attrs.to_h)
          # region は admin のみ更新可。一般ユーザーの指定値は破棄する。
          attributes.delete(:region) unless user.admin?

          if attributes.key?(:is_reference)
            requested_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(attributes[:is_reference]) || false
            reference_changed = requested_reference != pest[:is_reference]

            if reference_changed
              if requested_reference
                attributes[:user_id] = nil
              else
                attributes[:user_id] = user.id
              end
            end
          end

          attributes
        end
      end
    end
  end
end
