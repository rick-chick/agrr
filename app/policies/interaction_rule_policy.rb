# frozen_string_literal: true

class InteractionRulePolicy
  InteractionRule.include(ReferencableResourcePolicy) unless InteractionRule.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な InteractionRule 一覧スコープ
  def self.visible_scope(user)
    InteractionRule.visible_scope_for(user)
  end
end
