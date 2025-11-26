# frozen_string_literal: true

class AgriculturalTaskPolicy
  AgriculturalTask.include(ReferencableResourcePolicy) unless AgriculturalTask.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な AgriculturalTask 一覧スコープ
  def self.visible_scope(user)
    AgriculturalTask.visible_scope_for(user)
  end

  # show 用の1件取得
  # - 管理者: すべてのタスクにアクセス可能
  # - 一般ユーザー: 参照タスク または 自分のタスク
  def self.find_visible!(user, id)
    task = AgriculturalTask.find(id)
    unless user.admin? || task.is_reference || task.user_id == user.id
      raise PolicyPermissionDenied
    end
    task
  end

  # 編集・更新・削除用の1件取得
  # - 管理者: すべてのタスクを編集可能
  # - 一般ユーザー: 自分の非参照タスクのみ
  def self.find_editable!(user, id)
    task = AgriculturalTask.find(id)
    allowed =
      if user.admin?
        true
      else
        !task.is_reference && task.user_id == user.id
      end

    raise PolicyPermissionDenied unless allowed

    task
  end
end
