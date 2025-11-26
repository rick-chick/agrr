# frozen_string_literal: true

class FertilizePolicy
  Fertilize.include(ReferencableResourcePolicy) unless Fertilize.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Fertilize 一覧スコープ
  # Usage: FertilizePolicy.visible_scope(user)
  def self.visible_scope(user)
    Fertilize.visible_scope_for(user)
  end

  # 一覧スコープに基づいて1件取得（見えるもの＝編集可能なもの）
  # - 存在しないID      : ActiveRecord::RecordNotFound
  # - 存在するが権限なし: PolicyPermissionDenied
  def self.find_visible!(user, id)
    fertilize = Fertilize.find(id)
    unless visible_scope(user).exists?(id: fertilize.id)
      raise PolicyPermissionDenied
    end
    fertilize
  end

  # Fertilize では「見えるもの＝編集可能なもの」とする
  def self.find_editable!(user, id)
    find_visible!(user, id)
  end
end
