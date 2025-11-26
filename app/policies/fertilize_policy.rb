# frozen_string_literal: true

class FertilizePolicy
  Fertilize.include(ReferencableResourcePolicy) unless Fertilize.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Fertilize 一覧スコープ
  # Usage: FertilizePolicy.visible_scope(user)
  def self.visible_scope(user)
    Fertilize.visible_scope_for(user)
  end
end
