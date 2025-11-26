 # frozen_string_literal: true

class PlanPolicy
  # CultivationPlan のアクセスポリシー
  #
  # - 本ポリシーは「private plan（ユーザー所有の計画）」と「public plan（公開計画）」を対象とする
  # - private plan: ユーザー所有の計画（plan_type: private, user_id: user.id）
  # - public plan: 公開計画（plan_type: public, 認証不要で全公開）

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

  # public plan のスコープ（認証不要で全公開）
  # Usage: PlanPolicy.public_scope
  def self.public_scope
    CultivationPlan.plan_type_public
  end

  # public plan を1件取得（存在しない場合は RecordNotFound）
  # - plan_type: public
  # - 認証不要で全公開
  def self.find_public!(id)
    plan = CultivationPlan.find(id)

    raise PolicyPermissionDenied unless plan.plan_type_public?

    plan
  end
end

