# frozen_string_literal: true

class AgriculturalTaskPolicy
  AgriculturalTask.include(ReferencableResourcePolicy) unless AgriculturalTask.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な AgriculturalTask 一覧スコープ
  def self.visible_scope(user)
    AgriculturalTask.visible_scope_for(user)
  end
end
