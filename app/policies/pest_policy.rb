# frozen_string_literal: true

class PestPolicy
  Pest.include(ReferencableResourcePolicy) unless Pest.singleton_class.included_modules.include?(ReferencableResourcePolicy)

  # ユーザーにとって閲覧可能な Pest 一覧スコープ
  # - 管理者: 参照害虫 + 自分の害虫
  # - 一般ユーザー: 自分の非参照害虫のみ
  def self.visible_scope(user)
    Pest.visible_scope_for(user)
  end

  # 選択可能な Pest 一覧スコープ（参照データも含む）
  # - 管理者: 参照害虫 + 自分の害虫
  # - 一般ユーザー: 参照害虫 + 自分の害虫（選択候補として参照データも含む）
  def self.selectable_scope(user)
    Pest.where("is_reference = ? OR user_id = ?", true, user.id)
  end

  # create 用ビルダー
  # - 管理者: is_reference=true なら user_id=nil / false なら user_id=admin.id
  # - 一般ユーザー: is_reference は controller 側で false に強制・user_id=current_user.id に強制
  def self.build_for_create(user, params, admin_forced: false)
    attrs = params.to_h
    is_reference = ActiveModel::Type::Boolean.new.cast(attrs[:is_reference]) || false

    if user.admin? || admin_forced
      # 管理者作成時のルール
      if is_reference
        attrs[:user_id] = nil
        attrs[:is_reference] = true
      else
        attrs[:user_id] ||= user.id
        attrs[:is_reference] = false
      end
    else
      # 一般ユーザーは常にユーザー害虫
      attrs[:user_id] = user.id
      attrs[:is_reference] = false
    end

    Pest.new(attrs)
  end

  # show 用の1件取得
  # - 参照害虫 または 自分の害虫（管理者も他人のユーザー害虫にはアクセス不可）
  def self.find_visible!(user, id)
    pest = Pest.find(id)
    unless pest.is_reference || pest.user_id == user.id
      raise PolicyPermissionDenied
    end
    pest
  end

  # 編集・更新・削除用の1件取得
  # - 管理者: 参照害虫 + 自分の害虫
  # - 一般ユーザー: 自分の非参照害虫のみ
  def self.find_editable!(user, id)
    pest = Pest.find(id)

    allowed =
      if user.admin?
        # 参照害虫または自分の害虫のみ編集可能
        pest.is_reference || pest.user_id == user.id
      else
        # 一般ユーザーは自分の非参照害虫のみ編集可能
        !pest.is_reference && pest.user_id == user.id
      end

    raise PolicyPermissionDenied unless allowed

    pest
  end

  # update 用適用メソッド
  # - is_reference の変更可否そのものは controller 側でガード
  # - ここでは is_reference が変わる場合のみ user_id を整合させる
  def self.apply_update!(user, pest, params)
    attrs = params.to_h

    if attrs.key?(:is_reference)
      requested_reference = ActiveModel::Type::Boolean.new.cast(attrs[:is_reference]) || false
      reference_changed = requested_reference != pest.is_reference

      if reference_changed
        if requested_reference
          # 参照化: システム所有
          attrs[:user_id] = nil
        else
          # 非参照化: 編集ユーザー所有（到達するのは管理者のみ）
          attrs[:user_id] = user.id
        end
      end
    end

    pest.update(attrs)
  end
end
