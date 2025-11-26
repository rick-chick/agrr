# frozen_string_literal: true

# Pest-Crop 関連付けのポリシー
#
# 責務:
# - 害虫と作物の関連付け可否を判定する
# - 害虫に対して選択可能な作物のスコープを提供する
#
# ルール:
# - region が一致している必要がある（害虫に region が設定されている場合）
# - 参照害虫は参照作物のみ関連付け可能
# - ユーザー害虫は、そのユーザーの非参照作物のみ関連付け可能
class PestCropAssociationPolicy
  # 害虫に対して選択可能な作物のスコープを返す
  #
  # @param pest [Pest] 対象の害虫
  # @param user [User, nil] 現在のユーザー（オプション、pest.user_id が nil の場合に使用）
  # @return [ActiveRecord::Relation<Crop>] 選択可能な作物のスコープ
  def self.accessible_crops_scope(pest, user: nil)
    scope =
      if pest.is_reference?
        Crop.where(is_reference: true)
      else
        owner_id = pest.user_id || user&.id
        Crop.where(is_reference: false, user_id: owner_id)
      end

    # region が設定されている場合は region でフィルタ
    if pest.region.present?
      scope = scope.where(region: pest.region)
    end

    scope.order(:name)
  end

  # 特定の作物が害虫と関連付け可能か判定する
  #
  # @param crop [Crop] 対象の作物
  # @param pest [Pest] 対象の害虫
  # @param user [User, nil] 現在のユーザー（オプション、pest.user_id が nil の場合に使用）
  # @return [Boolean] 関連付け可能な場合 true
  def self.crop_accessible_for_pest?(crop, pest, user: nil)
    # 地域チェック（害虫に地域が設定されている場合）
    if pest.region.present?
      return false if crop.region != pest.region
    end

    # 参照害虫は参照作物のみに関連付け可能
    if pest.is_reference?
      return crop.is_reference?
    end

    # ユーザー所有の害虫は、自分の作物のみに関連付け可能
    owner_id = pest.user_id || user&.id
    crop.user_id == owner_id && !crop.is_reference?
  end
end
