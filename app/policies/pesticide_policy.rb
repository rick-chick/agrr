# frozen_string_literal: true

class PesticidePolicy
  Pesticide.include(ReferencableResourcePolicy) unless Pesticide.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Pesticide 一覧スコープ
  def self.visible_scope(user)
    Pesticide.visible_scope_for(user)
  end

  # 一覧スコープに基づいて1件取得（見えるもの＝編集可能なもの）
  # - 存在しないID      : ActiveRecord::RecordNotFound
  # - 存在するが権限なし: PolicyPermissionDenied
  def self.find_visible!(user, id)
    pesticide = Pesticide.find(id)
    unless visible_scope(user).exists?(id: pesticide.id)
      raise PolicyPermissionDenied
    end
    pesticide
  end

  # Pesticide では「見えるもの＝編集可能なもの」とする
  def self.find_editable!(user, id)
    find_visible!(user, id)
  end
end
