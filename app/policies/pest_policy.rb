# frozen_string_literal: true

class PestPolicy
  Pest.include(ReferencableResourcePolicy) unless Pest.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Pest 一覧スコープ
  def self.visible_scope(user)
    Pest.visible_scope_for(user)
  end
end
