# frozen_string_literal: true

module Domain
  module Shared
    # app/policies/pest_crop_association_policy.rb と同一ルール（アダプターは本クラスのみ参照する）。
    class PestCropAssociationAccess
      def self.accessible_crops_scope(pest, user: nil)
        scope =
          if pest.is_reference?
            ::Crop.where(is_reference: true)
          else
            owner_id = pest.user_id || user&.id
            ::Crop.where(is_reference: false, user_id: owner_id)
          end

        if pest.region.present?
          scope = scope.where(region: pest.region)
        end

        scope.order(:name)
      end

      def self.crop_accessible_for_pest?(crop, pest, user: nil)
        if pest.region.present?
          return false if crop.region != pest.region
        end

        if pest.is_reference?
          return crop.is_reference?
        end

        owner_id = pest.user_id || user&.id
        crop.user_id == owner_id && !crop.is_reference?
      end
    end
  end
end
