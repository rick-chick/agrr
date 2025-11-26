# frozen_string_literal: true

class InteractionRulePolicy
  InteractionRule.include(ReferencableResourcePolicy) unless InteractionRule.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な InteractionRule 一覧スコープ
  def self.visible_scope(user)
    InteractionRule.visible_scope_for(user)
  end

  # show 用の1件取得
  # - 管理者: すべてのルールにアクセス可能
  # - 一般ユーザー: 自分のルールのみ
  def self.find_visible!(user, id)
    rule = InteractionRule.find(id)
    unless user.admin? || rule.user_id == user.id
      raise PolicyPermissionDenied
    end
    rule
  end

  # 編集・更新・削除用の1件取得
  # - 管理者: すべてのルールを編集可能
  # - 一般ユーザー: user_owned（非参照）かつ自分のルールのみ
  def self.find_editable!(user, id)
    rule = InteractionRule.find(id)
    unless user.admin? || (!rule.is_reference && rule.user_id == user.id)
      raise PolicyPermissionDenied
    end
    rule
  end
end
