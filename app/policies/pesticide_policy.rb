# frozen_string_literal: true

class PesticidePolicy
  Pesticide.include(ReferencableResourcePolicy) unless Pesticide.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Pesticide 一覧スコープ
  def self.visible_scope(user)
    Pesticide.visible_scope_for(user)
  end
end
