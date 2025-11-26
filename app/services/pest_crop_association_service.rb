# frozen_string_literal: true

# Pest-Crop 関連付けサービス
#
# 責務:
# - 害虫と作物の関連付け・更新を実行する
# - Policy を利用して関連付け可否を判定し、許可されたもののみ関連付ける
class PestCropAssociationService
  # 害虫と作物を関連付ける
  #
  # @param pest [Pest] 対象の害虫
  # @param crop_ids [Array<Integer>, Array<String>] 関連付ける作物IDの配列
  # @param user [User, nil] 現在のユーザー（オプション）
  # @return [Integer] 関連付けられた作物の数
  def self.associate_crops(pest, crop_ids, user: nil)
    associated_count = 0

    Array(crop_ids).each do |crop_id|
      crop = Crop.find_by(id: crop_id)
      next unless crop

      # Policy で関連付け可否を判定
      next unless PestCropAssociationPolicy.crop_accessible_for_pest?(crop, pest, user: user)

      # 既に関連付けられていない場合のみ追加
      unless pest.crops.include?(crop)
        pest.crops << crop
        associated_count += 1
      end
    end

    associated_count
  end

  # 害虫と作物の関連付けを更新する（差分更新）
  #
  # @param pest [Pest] 対象の害虫
  # @param crop_ids [Array<Integer>, Array<String>] 新しい関連付け対象の作物IDの配列
  # @param user [User, nil] 現在のユーザー（オプション）
  # @return [Hash] { added: Integer, removed: Integer } 追加・削除された関連付けの数
  def self.update_crop_associations(pest, crop_ids, user: nil)
    new_ids = Array(crop_ids).map(&:to_i).uniq
    current_ids = pest.crop_ids

    # 削除すべき関連付け（現在あるが選択されていない）
    to_remove = current_ids - new_ids
    removed_count = 0
    to_remove.each do |crop_id|
      crop = Crop.find_by(id: crop_id)
      next unless crop

      pest.crops.delete(crop)
      removed_count += 1
    end

    # 追加すべき関連付け（選択されているが現在ない）
    to_add = new_ids - current_ids
    added_count = associate_crops(pest, to_add, user: user)

    { added: added_count, removed: removed_count }
  end

  # 作物IDの配列を正規化する（選択可能な作物IDのみを抽出）
  #
  # @param pest [Pest] 対象の害虫
  # @param raw_ids [Array, String, nil] 生の作物ID（文字列、数値、配列など）
  # @param user [User, nil] 現在のユーザー（オプション）
  # @return [Array<Integer>] 正規化された作物IDの配列
  def self.normalize_crop_ids(pest, raw_ids, user: nil)
    allowed_ids = accessible_crops_scope(pest, user: user).pluck(:id)
    Array(raw_ids).compact.reject(&:blank?).map(&:to_i).uniq & allowed_ids
  end

  # 害虫に対して選択可能な作物のスコープを返す（Policy への委譲）
  #
  # @param pest [Pest] 対象の害虫
  # @param user [User, nil] 現在のユーザー（オプション）
  # @return [ActiveRecord::Relation<Crop>] 選択可能な作物のスコープ
  def self.accessible_crops_scope(pest, user: nil)
    PestCropAssociationPolicy.accessible_crops_scope(pest, user: user)
  end
end
