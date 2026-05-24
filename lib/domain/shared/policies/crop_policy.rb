# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class CropPolicy
        def self.view_allowed?(user, is_reference:, user_id:)
          user.admin? || is_reference || user_id == user.id
        end

        def self.edit_allowed?(user, is_reference:, user_id:)
          user.admin? || (!is_reference && user_id == user.id)
        end

        # @return [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def self.index_list_filter(user)
          mode = user.admin? ? :reference_or_owned : :owned_non_reference
          Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: mode, user_id: user.id)
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

        # current_attrs: { is_reference:, user_id:, ... } スナップショット
        def self.normalize_attrs_for_update(user, current_attrs, requested_attrs)
          Domain::Shared::Policies::ReferencableResourcePolicy
            .normalize_referencable_attrs_for_update(user, current_attrs, requested_attrs)
        end

        # 害虫との crop_pest 関連付け可否（ORM 非依存）。
        def self.crop_associable_with_pest?(
          user:,
          crop_is_reference:,
          crop_user_id:,
          crop_region:,
          pest_is_reference:,
          pest_user_id:,
          pest_region:
        )
          if Domain::Shared.present?(pest_region)
            return false if crop_region.to_s != pest_region.to_s
          end

          if pest_is_reference
            return crop_is_reference == true
          end

          return true if crop_is_reference == true

          owner_id = pest_user_id
          if owner_id.nil?
            return false if user.nil?

            owner_id = user.id
          end
          crop_user_id.to_i == owner_id.to_i
        end

        # AI 害虫作成時の affected_crops: 参照作物は常に可。匿名は不可。
        def self.ai_affected_crop_linkable?(
          user:,
          crop_is_reference:,
          crop_user_id:,
          crop_region:,
          pest_is_reference:,
          pest_user_id:,
          pest_region:
        )
          return true if crop_is_reference == true
          return false if user.nil? || (user.respond_to?(:anonymous?) && user.anonymous?)

          crop_associable_with_pest?(
            user: user,
            crop_is_reference: crop_is_reference,
            crop_user_id: crop_user_id,
            crop_region: crop_region,
            pest_is_reference: pest_is_reference,
            pest_user_id: pest_user_id,
            pest_region: pest_region
          )
        end
      end
    end
  end
end
