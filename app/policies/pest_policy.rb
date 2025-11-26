# frozen_string_literal: true

class PestPolicy
  Pest.include(ReferencableResourcePolicy) unless Pest.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Pest 一覧スコープ
  def self.visible_scope(user)
    Pest.visible_scope_for(user)
  end

  # show 用の1件取得
  # - 参照害虫 または 自分の害虫（管理者も他人のユーザー害虫にはアクセス不可）
  def self.find_visible!(user, id)
    pest = Pest.find(id)
    unless pest.is_reference || pest.user_id == user.id
      raise PolicyPermissionDenied
    end
    pest
  end

  # 編集・更新・削除用の1件取得
  # - 管理者: 参照害虫 + 自分の害虫
  # - 一般ユーザー: 自分の非参照害虫のみ
  def self.find_editable!(user, id)
    pest = Pest.find(id)

    allowed =
      if user.admin?
        # 参照害虫または自分の害虫のみ編集可能
        pest.is_reference || pest.user_id == user.id
      else
        # 一般ユーザーは自分の非参照害虫のみ編集可能
        !pest.is_reference && pest.user_id == user.id
      end

    raise PolicyPermissionDenied unless allowed

    pest
  end
end
