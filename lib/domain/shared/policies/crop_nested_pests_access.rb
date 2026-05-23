# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      # 作物ネスト害虫: 参照作物は誰でも可。非参照は所有者のみ（管理者の横断閲覧は不可）。
      class CropNestedPestsAccess
        def self.assert_allowed!(user, crop_entity)
          is_reference = if crop_entity.respond_to?(:is_reference?)
                           crop_entity.is_reference?
                         else
                           !!crop_entity.is_reference
                         end
          return if is_reference || crop_entity.user_id == user.id

          raise Domain::Shared::Policies::PolicyPermissionDenied
        end
      end
    end
  end
end
