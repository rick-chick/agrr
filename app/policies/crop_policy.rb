# frozen_string_literal: true

class CropPolicy
  # Crop モデルに ReferencableResourcePolicy をミックスインして利用する
  Crop.include(ReferencableResourcePolicy) unless Crop.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Crop 一覧スコープ
  # Usage: CropPolicy.visible_scope(user)
  def self.visible_scope(user)
    Crop.visible_scope_for(user)
  end

  # TODO: 編集可能スコープや参照フラグ更新可否などは今後拡張予定
end
