# frozen_string_literal: true

# Pesticide-Crop/Pest 関連付けのポリシー（レガシー名のまま Domain へ委譲）
class PesticideAssociationPolicy
  def self.accessible_crops_scope(user)
    Domain::Shared::PesticideAssociationAccess.accessible_crops_scope(user)
  end

  def self.accessible_pests_scope(user)
    Domain::Shared::PesticideAssociationAccess.accessible_pests_scope(user)
  end
end
