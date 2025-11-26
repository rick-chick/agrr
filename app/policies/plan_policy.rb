 # frozen_string_literal: true

class PlanPolicy
  # CultivationPlan のアクセスポリシー
  #
  # - 本ポリシーは「private plan（ユーザー所有の計画）」を対象とする
  # - public plan は PublicPlansController / PublicPlans API が個別に扱う

  # ユーザー所有の private 計画スコープ
  # Usage: PlanPolicy.private_scope(user)
  def self.private_scope(user)
    CultivationPlan.plan_type_private.by_user(user)
  end

  # ユーザー所有の private 計画1件を取得
  # - plan_type: private
  # - user_id: user.id
  def self.find_private_owned!(user, id)
    plan = CultivationPlan.find(id)

    allowed = plan.plan_type_private? && plan.user_id == user.id
    raise PolicyPermissionDenied unless allowed

    plan
  end
end

