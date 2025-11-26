# frozen_string_literal: true

class CropPolicy
  # Crop モデルに ReferencableResourcePolicy をミックスインして利用する
  Crop.include(ReferencableResourcePolicy) unless Crop.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Crop 一覧スコープ
  # Usage: CropPolicy.visible_scope(user)
  def self.visible_scope(user)
    Crop.visible_scope_for(user)
  end

  # show 用の1件取得
  # - 管理者: すべての作物にアクセス可能
  # - 一般ユーザー: 参照作物 または 自分の作物
  def self.find_visible!(user, id)
    crop = Crop.find(id)
    unless user.admin? || crop.is_reference || crop.user_id == user.id
      raise PolicyPermissionDenied
    end
    crop
  end

  # 編集・更新・削除用の1件取得
  # - 管理者: すべての作物を編集可能
  # - 一般ユーザー: 自分の非参照作物のみ
  def self.find_editable!(user, id)
    crop = Crop.find(id)
    allowed =
      if user.admin?
        true
      else
        !crop.is_reference && crop.user_id == user.id
      end

    raise PolicyPermissionDenied unless allowed

    crop
  end
end
