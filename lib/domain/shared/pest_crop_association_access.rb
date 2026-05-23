# frozen_string_literal: true

module Domain
  module Shared
    # 認可ルール（ORM 非依存）。スコープ構築は Adapters::Pest::Persistence::PestCropAssociationScopes
    class PestCropAssociationAccess
      def self.crop_accessible_for_pest?(crop, pest, user: nil)
        if pest.region.present?
          return false if crop.region != pest.region
        end

        if reference?(pest)
          return reference?(crop)
        end

        # ユーザー害虫: 参照作物または同じ所有者の非参照作物に関連付け可能
        if reference?(crop)
          return true
        end

        owner_id = pest.user_id || user&.id
        crop.user_id == owner_id
      end

      def self.reference?(record)
        return record.reference? if record.respond_to?(:reference?)
        return record.is_reference? if record.respond_to?(:is_reference?)

        !!record.is_reference
      end
      private_class_method :reference?
    end
  end
end
