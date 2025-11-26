# frozen_string_literal: true

# Pesticide-Crop/Pest 関連付けのポリシー
#
# 責務:
# - 農薬に対して選択可能な作物・害虫のスコープを提供する
#
# ルール:
# - 管理者: 参照データ + 自分のデータ
# - 一般ユーザー: 自分の非参照データのみ
class PesticideAssociationPolicy
  # 農薬に対して選択可能な作物のスコープを返す
  #
  # @param user [User] 現在のユーザー
  # @return [ActiveRecord::Relation<Crop>] 選択可能な作物のスコープ
  def self.accessible_crops_scope(user)
    if user.admin?
      # 管理者: 参照作物 + 自分の作物
      Crop.where("is_reference = ? OR user_id = ?", true, user.id)
    else
      # 一般ユーザー: 自分の非参照作物のみ
      Crop.where(user_id: user.id, is_reference: false)
    end.order(:name)
  end

  # 農薬に対して選択可能な害虫のスコープを返す
  #
  # @param user [User] 現在のユーザー
  # @return [ActiveRecord::Relation<Pest>] 選択可能な害虫のスコープ
  def self.accessible_pests_scope(user)
    if user.admin?
      # 管理者: 参照害虫 + 自分の害虫
      Pest.where("is_reference = ? OR user_id = ?", true, user.id)
    else
      # 一般ユーザー: 自分の非参照害虫のみ
      Pest.where(user_id: user.id, is_reference: false)
    end.order(:name)
  end
end
