# frozen_string_literal: true

# Pest-Crop 関連付けのポリシー
# accessible_crops_scope: AR スコープ（app レイヤなので AR 使用可）
# crop_accessible_for_pest?: ドメインルール（Domain::Shared::PestCropAssociationAccess 委譲）
class PestCropAssociationPolicy
  def self.accessible_crops_scope(pest, user: nil)
    scope =
      if pest.is_reference?
        ::Crop.where(is_reference: true)
      else
        owner_id = pest.user_id || user&.id
        # ユーザー害虫: 同じ所有者の非参照作物 + 参照作物すべて
        ::Crop.where("is_reference = ? OR (is_reference = ? AND user_id = ?)", true, false, owner_id)
      end

    scope = scope.where(region: pest.region) if pest.region.present?
    scope.order(:name)
  end

  def self.crop_accessible_for_pest?(crop, pest, user: nil)
    Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: user)
  end
end
