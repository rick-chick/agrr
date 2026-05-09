# frozen_string_literal: true

# Pest-Crop 関連付けのポリシー（レガシー名のまま Domain へ委譲）
class PestCropAssociationPolicy
  def self.accessible_crops_scope(pest, user: nil)
    Domain::Shared::PestCropAssociationAccess.accessible_crops_scope(pest, user: user)
  end

  def self.crop_accessible_for_pest?(crop, pest, user: nil)
    Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: user)
  end
end
